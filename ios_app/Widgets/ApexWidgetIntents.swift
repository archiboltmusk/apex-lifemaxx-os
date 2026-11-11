import Foundation
import WidgetKit
#if canImport(AppIntents) && !os(watchOS)
import AppIntents

@available(iOS 17.0, *)
public struct WidgetLogHydrationIntent: AppIntent {
    public static var title: LocalizedStringResource = "Log +250 mL Water"
    public static var description = IntentDescription("Adds 250 mL hydration to today's APEX OS log from your Home Screen.")

    public init() {}

    public func perform() async throws -> some IntentResult {
        ApexSnapshotStore.queueHydrationIncrement(ml: 250)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

@available(iOS 17.0, *)
public struct WidgetToggleSunlightIntent: AppIntent {
    public static var title: LocalizedStringResource = "Toggle Morning Sunlight"
    public static var description = IntentDescription("Logs morning sunlight exposure into your APEX OS N-of-1 Journal.")

    public init() {}

    public func perform() async throws -> some IntentResult {
        ApexSnapshotStore.queuePendingJournalTag("sunlight")
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
#endif
