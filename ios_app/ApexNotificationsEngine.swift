import Foundation
import UserNotifications

// MARK: - Proactive Morning Briefing, Health Monitor Illness Alert & Caffeine Cutoff Scheduler
@MainActor
public final class ApexNotificationsEngine: ObservableObject {
    public static let shared = ApexNotificationsEngine()

    @Published public var isAuthorized: Bool = false
    @Published public var morningBriefingEnabled: Bool {
        didSet {
            UserDefaults.standard.set(morningBriefingEnabled, forKey: "apex_notif_morning")
            rescheduleAll(health: HealthKitManager.shared)
        }
    }
    @Published public var outOfRangeAlertsEnabled: Bool {
        didSet { UserDefaults.standard.set(outOfRangeAlertsEnabled, forKey: "apex_notif_vitals") }
    }
    @Published public var caffeineCutoffEnabled: Bool {
        didSet {
            UserDefaults.standard.set(caffeineCutoffEnabled, forKey: "apex_notif_caffeine")
            rescheduleAll(health: HealthKitManager.shared)
        }
    }
    @Published public var morningHour: Int {
        didSet {
            UserDefaults.standard.set(morningHour, forKey: "apex_notif_morning_hour")
            rescheduleAll(health: HealthKitManager.shared)
        }
    }
    @Published public var morningMinute: Int {
        didSet {
            UserDefaults.standard.set(morningMinute, forKey: "apex_notif_morning_min")
            rescheduleAll(health: HealthKitManager.shared)
        }
    }

    private let center = UNUserNotificationCenter.current()

    private init() {
        let d = UserDefaults.standard
        self.morningBriefingEnabled = d.object(forKey: "apex_notif_morning") as? Bool ?? true
        self.outOfRangeAlertsEnabled = d.object(forKey: "apex_notif_vitals") as? Bool ?? true
        self.caffeineCutoffEnabled = d.object(forKey: "apex_notif_caffeine") as? Bool ?? true
        self.morningHour = d.object(forKey: "apex_notif_morning_hour") as? Int ?? 7
        self.morningMinute = d.object(forKey: "apex_notif_morning_min") as? Int ?? 30
        Task { await refreshAuthorizationStatus() }
    }

    public func refreshAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }

    public func requestAuthorization(health: HealthKitManager) async -> Bool {
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        isAuthorized = granted
        if granted {
            rescheduleAll(health: health)
        }
        return granted
    }

    public func evaluateHealthMonitorAndSchedule(health: HealthKitManager) {
        guard isAuthorized else { return }
        rescheduleAll(health: health)

        guard outOfRangeAlertsEnabled else { return }
        let monitor = health.vitalRangeSummary
        // Trigger early warning only when >=3 real vitals measured and >=2 are outside baseline
        guard monitor.total >= 3, (monitor.total - monitor.inRange) >= 2 else { return }

        let todayKey = Self.dayKey()
        let lastKey = UserDefaults.standard.string(forKey: "apex_last_vital_alert_day")
        guard lastKey != todayKey else { return }
        UserDefaults.standard.set(todayKey, forKey: "apex_last_vital_alert_day")

        let content = UNMutableNotificationContent()
        content.title = "APEX Health Monitor: Recovery Attention"
        content.body = "\(monitor.total - monitor.inRange) of \(monitor.total) overnight vitals shifted outside personal baseline. Favor Zone 2 / rest today."
        content.sound = .default

        let req = UNNotificationRequest(
            identifier: "apex.vitals.warning.\(todayKey)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        )
        center.add(req)
    }

    public func rescheduleAll(health: HealthKitManager) {
        guard isAuthorized else { return }
        center.removePendingNotificationRequests(withIdentifiers: ["apex.morning.briefing", "apex.caffeine.cutoff", "apex.winddown"])

        if morningBriefingEnabled {
            let content = UNMutableNotificationContent()
            content.title = "APEX Morning Briefing Ready"
            let rdy = health.readinessScore.map { "\($0)% Readiness" } ?? "Sync HealthKit"
            let target = health.targetStrainRange.map { String(format: " · Target Strain %.0f–%.0f", $0.lowerBound, $0.upperBound) } ?? ""
            content.body = "\(rdy)\(target). Open Summary for Energy Bank & Sleep Coach."
            content.sound = .default

            var comps = DateComponents()
            comps.hour = morningHour
            comps.minute = morningMinute
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            center.add(UNNotificationRequest(identifier: "apex.morning.briefing", content: content, trigger: trigger))
        }

        if caffeineCutoffEnabled {
            let wakeMin = UserDefaults.standard.object(forKey: "apex_wake_minutes") as? Int ?? 390
            let cutoffTotalMin = (wakeMin + 450) % 1440 // 7.5h post-wake caffeine cutoff
            let cutContent = UNMutableNotificationContent()
            cutContent.title = "Caffeine Cutoff Window"
            cutContent.body = "Clear remaining adenosine receptors before tonight's recovery sleep."
            cutContent.sound = .default

            var cutComps = DateComponents()
            cutComps.hour = cutoffTotalMin / 60
            cutComps.minute = cutoffTotalMin % 60
            center.add(UNNotificationRequest(
                identifier: "apex.caffeine.cutoff",
                content: cutContent,
                trigger: UNCalendarNotificationTrigger(dateMatching: cutComps, repeats: true)
            ))

            let windMin = (wakeMin + 930) % 1440 // ~15.5h post-wake wind-down
            let windContent = UNMutableNotificationContent()
            windContent.title = "Circadian Wind-Down"
            let needTxt = health.sleepNeededHours.map { String(format: " Aim for %.1fh tonight.", $0) } ?? ""
            windContent.body = "Dim overhead lights for melatonin onset.\(needTxt)"
            windContent.sound = .default

            var windComps = DateComponents()
            windComps.hour = windMin / 60
            windComps.minute = windMin % 60
            center.add(UNNotificationRequest(
                identifier: "apex.winddown",
                content: windContent,
                trigger: UNCalendarNotificationTrigger(dateMatching: windComps, repeats: true)
            ))
        }
    }

    private static func dayKey() -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}
