import WidgetKit
import SwiftUI
import ActivityKit

// MARK: - Widget Timeline Entry & Provider
struct ApexWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: ApexWidgetSnapshot
}

struct ApexTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> ApexWidgetEntry {
        ApexWidgetEntry(date: Date(), snapshot: ApexWidgetSnapshot())
    }

    func getSnapshot(in context: Context, completion: @escaping (ApexWidgetEntry) -> Void) {
        completion(ApexWidgetEntry(date: Date(), snapshot: ApexSnapshotStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ApexWidgetEntry>) -> Void) {
        let entry = ApexWidgetEntry(date: Date(), snapshot: ApexSnapshotStore.load())
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

// MARK: - Home & Lock Screen Widget Views
struct ApexReadinessWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ApexWidgetEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                ZStack {
                    AccessoryWidgetBackground()
                    VStack(spacing: 1) {
                        Text(entry.snapshot.readinessScore.map { "\($0)" } ?? "—")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text("RDY")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                }
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 2) {
                    Text("APEX READINESS")
                        .font(.system(size: 10, weight: .bold))
                    Text(entry.snapshot.readinessScore.map { "\($0)% Recovery" } ?? "Sync Apple Health")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                    Text("Move \(Int(entry.snapshot.moveCalories))/\(Int(entry.snapshot.moveTarget)) kcal")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            case .systemSmall:
                smallWidget
            default:
                mediumWidget
            }
        }
        .widgetURL(URL(string: "apex://summary"))
        .containerBackground(Color.black, for: .widget)
    }

    private var smallWidget: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("APEX")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(red: 0.90, green: 0.99, blue: 0.25))
                Spacer()
                Image(systemName: "heart.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(red: 0.98, green: 0.07, blue: 0.31))
            }

            Spacer()

            Text(entry.snapshot.readinessScore.map { "\($0)%" } ?? "—")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)

            Text(entry.snapshot.hrv.map { "HRV \(Int($0.rounded())) ms" } ?? "Readiness")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            ProgressView(value: min(1.0, entry.snapshot.moveCalories / max(1, entry.snapshot.moveTarget)))
                .tint(Color(red: 0.98, green: 0.07, blue: 0.31))
        }
    }

    private var mediumWidget: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("READINESS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color(red: 0.90, green: 0.99, blue: 0.25))
                Text(entry.snapshot.readinessScore.map { "\($0)%" } ?? "—")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                Text(entry.snapshot.biologicalAge.map { String(format: "Bio Age %.1fy", $0) } ?? "Connect Health")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .leading, spacing: 8) {
                statLine("Move", "\(Int(entry.snapshot.moveCalories)) kcal", Color(red: 0.98, green: 0.07, blue: 0.31))
                statLine("Exercise", "\(Int(entry.snapshot.exerciseMinutes)) min", Color(red: 0.58, green: 0.98, blue: 0.16))
                statLine("HRV", entry.snapshot.hrv.map { "\(Int($0.rounded())) ms" } ?? "—", Color(red: 0.00, green: 0.84, blue: 0.96))
            }
        }
    }

    private func statLine(_ title: String, _ val: String, _ color: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(val)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
    }
}

struct ApexReadinessWidget: Widget {
    let kind: String = "ApexReadinessWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ApexTimelineProvider()) { entry in
            ApexReadinessWidgetView(entry: entry)
        }
        .configurationDisplayName("APEX Readiness & Rings")
        .description("Live autonomic recovery, HRV, and Activity rings at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

// MARK: - Live Activity (Dynamic Island + Lock Screen Banner)
@available(iOS 16.1, *)
struct ApexWorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ApexWorkoutAttributes.self) { context in
            // Lock Screen / StandBy Banner
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(context.attributes.exerciseName.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(red: 0.90, green: 0.99, blue: 0.25))
                    if context.state.isResting {
                        Text("Rest \(formatTime(context.state.restSecondsRemaining))")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Color(red: 0.00, green: 0.84, blue: 0.96))
                    } else {
                        Text("\(context.state.reps) reps")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(formatTime(context.state.elapsedSeconds))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                    Text(String(format: "%.2f m/s · -%d%%", context.state.lastVelocity, context.state.velocityDropPercent))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .activityBackgroundTint(.black)
            .activitySystemActionForegroundColor(Color(red: 0.90, green: 0.99, blue: 0.25))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading) {
                        Text(context.attributes.exerciseName)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color(red: 0.90, green: 0.99, blue: 0.25))
                        Text("\(context.state.reps) reps")
                            .font(.title3.weight(.bold))
                            .monospacedDigit()
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing) {
                        Text(context.state.isResting ? "REST" : "SET")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                        Text(formatTime(context.state.isResting ? context.state.restSecondsRemaining : context.state.elapsedSeconds))
                            .font(.title3.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(Color(red: 0.00, green: 0.84, blue: 0.96))
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(String(format: "Peak Velocity %.2f m/s · Velocity Loss -%d%%", context.state.lastVelocity, context.state.velocityDropPercent))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Text("\(context.state.reps)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.90, green: 0.99, blue: 0.25))
            } compactTrailing: {
                Text(formatTime(context.state.isResting ? context.state.restSecondsRemaining : context.state.elapsedSeconds))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(context.state.isResting ? Color(red: 0.00, green: 0.84, blue: 0.96) : .white)
            } minimal: {
                Image(systemName: "figure.strengthtraining.traditional")
                    .foregroundStyle(Color(red: 0.90, green: 0.99, blue: 0.25))
            }
            .widgetURL(URL(string: "apex://train"))
        }
    }

    private func formatTime(_ sec: Int) -> String {
        String(format: "%d:%02d", sec / 60, sec % 60)
    }
}

@main
struct ApexWidgetsBundle: WidgetBundle {
    var body: some Widget {
        ApexReadinessWidget()
        if #available(iOS 16.1, *) {
            ApexWorkoutLiveActivity()
        }
    }
}
