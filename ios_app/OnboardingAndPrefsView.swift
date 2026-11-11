import SwiftUI
import StoreKit

// MARK: - Native StoreKit 2 Membership & Entitlements Engine
@MainActor
public final class ApexStoreManager: ObservableObject {
    public static let shared = ApexStoreManager()

    public static let productIDs = [
        "club.apex.pro.monthly",
        "club.apex.pro.annual",
        "club.apex.pro.lifetime"
    ]

    @Published public private(set) var products: [Product] = []
    @Published public private(set) var activeProductID: String? = nil
    @Published public private(set) var isLoadingProducts: Bool = false
    @Published public var purchaseStatusMessage: String? = nil

    public var isProUnlocked: Bool { activeProductID != nil }

    private var updatesTask: Task<Void, Never>? = nil

    private init() {
        updatesTask = Task { await observeTransactionUpdates() }
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    public func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let loaded = try await Product.products(for: Self.productIDs)
            self.products = loaded.sorted { $0.price < $1.price }
            if loaded.isEmpty {
                self.purchaseStatusMessage = "App Store Connect / StoreKit configuration not linked on this unsigned build."
            }
        } catch {
            self.products = []
            self.purchaseStatusMessage = "StoreKit unavailable in current sandbox environment."
        }
    }

    public func refreshEntitlements() async {
        var foundID: String? = nil
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result, tx.revocationDate == nil {
                foundID = tx.productID
            }
        }
        self.activeProductID = foundID
    }

    public func purchase(_ product: Product) async {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await refreshEntitlements()
                    purchaseStatusMessage = "APEX Pro activated via App Store."
                    Haptics.success()
                } else {
                    purchaseStatusMessage = "Receipt verification failed."
                }
            case .userCancelled:
                purchaseStatusMessage = "Purchase cancelled."
            case .pending:
                purchaseStatusMessage = "Purchase pending App Store approval."
            @unknown default:
                purchaseStatusMessage = "Unknown StoreKit state."
            }
        } catch {
            purchaseStatusMessage = "Purchase failed: \(error.localizedDescription)"
        }
    }

    public func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            purchaseStatusMessage = isProUnlocked
                ? "Restored active APEX Pro entitlement."
                : "No active StoreKit purchases found on this Apple ID."
        } catch {
            purchaseStatusMessage = "App Store sync unavailable in local build."
        }
    }

    private func observeTransactionUpdates() async {
        for await result in Transaction.updates {
            if case .verified(let tx) = result {
                await tx.finish()
                await refreshEntitlements()
            }
        }
    }
}

// MARK: - StoreKit 2 APEX Pro Membership Sheet
public struct ApexProPaywallSheet: View {
    @ObservedObject private var store = ApexStoreManager.shared
    @Environment(\.dismiss) private var dismiss

    private struct PlanPreview: Identifiable {
        let id: String
        let title: String
        let badge: String
        let refPrice: String
        let desc: String
    }

    private let referenceTiers: [PlanPreview] = [
        PlanPreview(id: "club.apex.pro.annual", title: "APEX Pro Annual", badge: "BEST VALUE", refPrice: "$79.99 / yr", desc: "WatchOS Companion, Clinical PDF Dossier & Full N-of-1 Lab"),
        PlanPreview(id: "club.apex.pro.monthly", title: "APEX Pro Monthly", badge: "FLEXIBLE", refPrice: "$9.99 / mo", desc: "On-device Apple Intelligence Coach, CGM & Bloodwork OCR"),
        PlanPreview(id: "club.apex.pro.lifetime", title: "Founders Lifetime", badge: "UNLIMITED", refPrice: "$199.99 once", desc: "All future biomarker, spatial haptic & Continuity upgrades")
    ]

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    VStack(spacing: 8) {
                        Image(systemName: store.isProUnlocked ? "crown.fill" : "bolt.shield.fill")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(ApexTheme.accentVolt)
                        Text(store.isProUnlocked ? "APEX Pro Active" : "APEX Pro Membership")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("StoreKit 2 verified entitlements · Private on-device health compute")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 8)

                    if !store.products.isEmpty {
                        ForEach(store.products, id: \.id) { product in
                            let isActive = store.activeProductID == product.id
                            Button {
                                Haptics.tap(.medium)
                                Task { await store.purchase(product) }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(product.displayName)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(.white)
                                        Text(product.description)
                                            .font(.system(size: 12))
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(isActive ? "ACTIVE" : product.displayPrice)
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundStyle(isActive ? .black : ApexTheme.accentVolt)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(isActive ? ApexTheme.accentVolt : ApexTheme.elevatedSurface)
                                        .clipShape(Capsule())
                                }
                                .appleCard(padding: 16, cornerRadius: 18)
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("All On-Device Engines Unlocked Offline", systemImage: "checkmark.seal.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(ApexTheme.accentEmerald)
                            Text("All HealthKit, Bevel recovery/strain curves, Vision face & pose tracking, optical rPPG, Watch sync, PDF clinical reports, and local .apexbackup continuity run natively on your device.")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            Text("App Store Connect Pro/Supporter SKUs load automatically once published with your Apple Developer StoreKit configuration.")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .appleCard(padding: 16, cornerRadius: 18)
                    }

                    Button {
                        Haptics.selection()
                        Task { await store.restorePurchases() }
                    } label: {
                        Text("Restore App Store Purchases")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(ApexTheme.standCyan)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(ApexTheme.cardSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    if let status = store.purchaseStatusMessage {
                        Text(status)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
            }
            .background(ApexTheme.background.ignoresSafeArea())
            .navigationTitle("APEX Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - First-Run Calibration Onboarding Sheet
public struct CalibrationOnboardingSheet: View {
    @ObservedObject private var health = HealthKitManager.shared
    @ObservedObject private var nutrition = NutritionLogStore.shared
    @ObservedObject private var notifications = ApexNotificationsEngine.shared
    @ObservedObject private var watch = ApexWatchConnectivity.shared

    @AppStorage("apex_has_completed_onboarding") private var hasCompletedOnboarding: Bool = false
    @AppStorage(ApexUnitPreferences.unitKey) private var unitRaw: String = ApexUnitPreferences.current.rawValue
    @AppStorage("apex_wake_minutes") private var wakeMinutes: Int = 390
    @Environment(\.dismiss) private var dismiss

    private var wakeDateBinding: Binding<Date> {
        Binding<Date>(
            get: {
                Calendar.current.date(bySettingHour: wakeMinutes / 60, minute: wakeMinutes % 60, second: 0, of: Date()) ?? Date()
            },
            set: { newDate in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                wakeMinutes = (comps.hour ?? 6) * 60 + (comps.minute ?? 30)
                notifications.rescheduleAll(health: health)
            }
        )
    }

    public init() {}

    public var body: some View {
        NavigationStack {
            Form {
                Section("Baseline Calibration") {
                    Stepper("Chronological Age: \(Int(health.chronologicalAge)) yrs", value: Binding(
                        get: { health.chronologicalAge },
                        set: {
                            health.chronologicalAge = $0
                            health.isAgeManuallySet = true
                        }
                    ), in: 14...99)

                    Picker("Unit System", selection: $unitRaw) {
                        ForEach(ApexUnitSystem.allCases) { unit in
                            Text(unit.displayLabel).tag(unit.rawValue)
                        }
                    }
                    .onChange(of: unitRaw) { _, newVal in
                        if let parsed = ApexUnitSystem(rawValue: newVal) {
                            ApexUnitPreferences.current = parsed
                            Haptics.selection()
                        }
                    }

                    DatePicker("Typical Wake Time", selection: wakeDateBinding, displayedComponents: .hourAndMinute)
                }

                Section("Daily Targets") {
                    Stepper("Sleep Goal: \(String(format: "%.2f", health.baselineSleepGoalHours)) hrs", value: $health.baselineSleepGoalHours, in: 6.0...10.0, step: 0.25)
                    Stepper("Calorie Target: \(Int(nutrition.calorieTarget)) kcal", value: $nutrition.calorieTarget, in: 1200...5000, step: 100)
                    Stepper("Protein Target: \(Int(nutrition.proteinTargetG)) g", value: $nutrition.proteinTargetG, in: 60...320, step: 5)
                    Stepper("Fiber Target: \(Int(nutrition.fiberTargetG)) g", value: $nutrition.fiberTargetG, in: 15...80, step: 2)
                }

                Section("Real-Data Permissions & Wearables") {
                    Button {
                        Haptics.tap(.medium)
                        health.requestAuthorization()
                    } label: {
                        HStack {
                            Label("Connect Apple HealthKit", systemImage: "heart.text.square.fill")
                                .foregroundStyle(ApexTheme.moveCrimson)
                            Spacer()
                            Text(health.isAuthorized ? "Connected" : "Connect")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(health.isAuthorized ? ApexTheme.accentEmerald : ApexTheme.accentVolt)
                        }
                    }

                    Button {
                        Haptics.tap(.medium)
                        Task { _ = await notifications.requestAuthorization(health: health) }
                    } label: {
                        HStack {
                            Label("Proactive Vitals & Morning Alerts", systemImage: "bell.badge.fill")
                                .foregroundStyle(ApexTheme.standCyan)
                            Spacer()
                            Text(notifications.isAuthorized ? "Enabled" : "Allow")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(notifications.isAuthorized ? ApexTheme.accentEmerald : ApexTheme.accentVolt)
                        }
                    }

                    HStack {
                        Label("Apple Watch Bridge", systemImage: "applewatch")
                            .foregroundStyle(ApexTheme.exerciseLime)
                        Spacer()
                        Text(watch.isPaired ? (watch.isReachable ? "Live Reachable" : "Paired") : "Ready When Paired")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button {
                        Haptics.success()
                        hasCompletedOnboarding = true
                        dismiss()
                    } label: {
                        Text("Save Calibration & Enter APEX OS")
                            .font(.system(size: 16, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(ApexTheme.accentVolt)
                    }
                }
            }
            .navigationTitle("Calibrate APEX OS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Skip") {
                        hasCompletedOnboarding = true
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Alerts, Units & Watch Preferences Sheet
public struct AlertsAndPreferencesSheet: View {
    @ObservedObject private var health = HealthKitManager.shared
    @ObservedObject private var notifications = ApexNotificationsEngine.shared
    @ObservedObject private var watch = ApexWatchConnectivity.shared

    @AppStorage(ApexUnitPreferences.unitKey) private var unitRaw: String = ApexUnitPreferences.current.rawValue
    @AppStorage("apex_wake_minutes") private var wakeMinutes: Int = 390
    @Environment(\.dismiss) private var dismiss

    @State private var showOnboarding = false

    private var morningTimeBinding: Binding<Date> {
        Binding<Date>(
            get: {
                Calendar.current.date(bySettingHour: notifications.morningHour, minute: notifications.morningMinute, second: 0, of: Date()) ?? Date()
            },
            set: { newDate in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                notifications.morningHour = comps.hour ?? 7
                notifications.morningMinute = comps.minute ?? 30
            }
        )
    }

    private var wakeTimeBinding: Binding<Date> {
        Binding<Date>(
            get: {
                Calendar.current.date(bySettingHour: wakeMinutes / 60, minute: wakeMinutes % 60, second: 0, of: Date()) ?? Date()
            },
            set: { newDate in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                wakeMinutes = (comps.hour ?? 6) * 60 + (comps.minute ?? 30)
                notifications.rescheduleAll(health: health)
                Haptics.selection()
            }
        )
    }

    public init() {}

    public var body: some View {
        NavigationStack {
            Form {
                Section("Units & Display") {
                    Picker("Measurement Units", selection: $unitRaw) {
                        ForEach(ApexUnitSystem.allCases) { unit in
                            Text(unit.displayLabel).tag(unit.rawValue)
                        }
                    }
                    .onChange(of: unitRaw) { _, newVal in
                        if let parsed = ApexUnitSystem(rawValue: newVal) {
                            ApexUnitPreferences.current = parsed
                            Haptics.selection()
                        }
                    }
                    DatePicker("Typical Wake Time", selection: wakeTimeBinding, displayedComponents: .hourAndMinute)
                }

                Section("Proactive Intelligence Alerts") {
                    if !notifications.isAuthorized {
                        Button("Enable Push Notifications") {
                            Task { _ = await notifications.requestAuthorization(health: health) }
                        }
                        .foregroundStyle(ApexTheme.accentVolt)
                    } else {
                        Label("Notifications Authorized", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(ApexTheme.accentEmerald)
                    }

                    Toggle("Overnight 5-Vital Shift Alert", isOn: $notifications.outOfRangeAlertsEnabled)
                    Toggle("Morning Briefing Summary", isOn: $notifications.morningBriefingEnabled)
                    if notifications.morningBriefingEnabled {
                        DatePicker("Briefing Delivery Time", selection: morningTimeBinding, displayedComponents: .hourAndMinute)
                    }
                    Toggle("Caffeine Cutoff & Wind-Down Alerts", isOn: $notifications.caffeineCutoffEnabled)
                }

                Section("Apple Watch Continuity") {
                    LabeledContent("Watch Paired", value: watch.isPaired ? "Yes" : "No")
                    LabeledContent("Watch Reachable", value: watch.isReachable ? "Live" : "Standby")
                    if let lastSet = watch.lastWatchSetSummary {
                        LabeledContent("Last Watch Set", value: lastSet)
                    }
                    Button("Push Live Telemetry to Watch") {
                        Haptics.tap()
                        watch.pushTelemetryToWatch(health: health)
                    }
                    .foregroundStyle(ApexTheme.standCyan)
                }

                Section("Setup") {
                    Button("Open Calibration Wizard") {
                        showOnboarding = true
                    }
                }
            }
            .navigationTitle("Preferences & Alerts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
            .sheet(isPresented: $showOnboarding) {
                CalibrationOnboardingSheet()
            }
        }
        .preferredColorScheme(.dark)
    }
}
