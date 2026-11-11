import SwiftUI
import HealthKit

// MARK: - Bevel Strength Builder Data Models & Exercise Library
public struct BevelExercise: Identifiable, Codable, Hashable {
    public let id: String
    public let name: String
    public let category: String // Push, Pull, Legs, Core, Conditioning
    public let primaryMuscle: String
    public let secondaryMuscle: String?
    public let equipment: String
    public let isBodyweight: Bool

    public static let library: [BevelExercise] = [
        BevelExercise(id: "barbell_squat", name: "Barbell Back Squat", category: "Legs", primaryMuscle: "Quads", secondaryMuscle: "Glutes", equipment: "Barbell", isBodyweight: false),
        BevelExercise(id: "front_squat", name: "Barbell Front Squat", category: "Legs", primaryMuscle: "Quads", secondaryMuscle: "Core", equipment: "Barbell", isBodyweight: false),
        BevelExercise(id: "bulgarian_split", name: "Bulgarian Split Squat", category: "Legs", primaryMuscle: "Quads", secondaryMuscle: "Glutes", equipment: "Dumbbell", isBodyweight: false),
        BevelExercise(id: "leg_press", name: "Leg Press", category: "Legs", primaryMuscle: "Quads", secondaryMuscle: "Glutes", equipment: "Machine", isBodyweight: false),
        BevelExercise(id: "rdl", name: "Romanian Deadlift", category: "Legs", primaryMuscle: "Hamstrings", secondaryMuscle: "Glutes", equipment: "Barbell", isBodyweight: false),
        BevelExercise(id: "leg_curl", name: "Seated Leg Curl", category: "Legs", primaryMuscle: "Hamstrings", secondaryMuscle: nil, equipment: "Machine", isBodyweight: false),
        BevelExercise(id: "hip_thrust", name: "Barbell Hip Thrust", category: "Legs", primaryMuscle: "Glutes", secondaryMuscle: "Hamstrings", equipment: "Barbell", isBodyweight: false),
        BevelExercise(id: "calf_raise", name: "Standing Calf Raise", category: "Legs", primaryMuscle: "Calves", secondaryMuscle: nil, equipment: "Machine", isBodyweight: false),
        BevelExercise(id: "bench_press", name: "Barbell Bench Press", category: "Push", primaryMuscle: "Chest", secondaryMuscle: "Triceps", equipment: "Barbell", isBodyweight: false),
        BevelExercise(id: "incline_db", name: "Incline Dumbbell Press", category: "Push", primaryMuscle: "Chest", secondaryMuscle: "Shoulders", equipment: "Dumbbell", isBodyweight: false),
        BevelExercise(id: "weighted_dips", name: "Parallel Bar Dips", category: "Push", primaryMuscle: "Chest", secondaryMuscle: "Triceps", equipment: "Bodyweight", isBodyweight: true),
        BevelExercise(id: "cable_fly", name: "Cable Chest Fly", category: "Push", primaryMuscle: "Chest", secondaryMuscle: nil, equipment: "Cable", isBodyweight: false),
        BevelExercise(id: "ohp", name: "Overhead Barbell Press", category: "Push", primaryMuscle: "Shoulders", secondaryMuscle: "Triceps", equipment: "Barbell", isBodyweight: false),
        BevelExercise(id: "db_lateral", name: "Dumbbell Lateral Raise", category: "Push", primaryMuscle: "Shoulders", secondaryMuscle: nil, equipment: "Dumbbell", isBodyweight: false),
        BevelExercise(id: "tricep_pushdown", name: "Rope Tricep Pushdown", category: "Push", primaryMuscle: "Triceps", secondaryMuscle: nil, equipment: "Cable", isBodyweight: false),
        BevelExercise(id: "overhead_ext", name: "Overhead Tricep Extension", category: "Push", primaryMuscle: "Triceps", secondaryMuscle: nil, equipment: "Cable", isBodyweight: false),
        BevelExercise(id: "pushups", name: "Push-Ups", category: "Push", primaryMuscle: "Chest", secondaryMuscle: "Triceps", equipment: "Bodyweight", isBodyweight: true),
        BevelExercise(id: "deadlift", name: "Conventional Deadlift", category: "Pull", primaryMuscle: "Hamstrings", secondaryMuscle: "Lats", equipment: "Barbell", isBodyweight: false),
        BevelExercise(id: "pullups", name: "Pull-Ups", category: "Pull", primaryMuscle: "Lats", secondaryMuscle: "Biceps", equipment: "Bodyweight", isBodyweight: true),
        BevelExercise(id: "lat_pulldown", name: "Wide-Grip Lat Pulldown", category: "Pull", primaryMuscle: "Lats", secondaryMuscle: "Biceps", equipment: "Cable", isBodyweight: false),
        BevelExercise(id: "barbell_row", name: "Bent-Over Barbell Row", category: "Pull", primaryMuscle: "Lats", secondaryMuscle: "Upper Back", equipment: "Barbell", isBodyweight: false),
        BevelExercise(id: "chest_supported_row", name: "Chest-Supported Row", category: "Pull", primaryMuscle: "Upper Back", secondaryMuscle: "Lats", equipment: "Machine", isBodyweight: false),
        BevelExercise(id: "face_pull", name: "Rope Face Pulls", category: "Pull", primaryMuscle: "Shoulders", secondaryMuscle: "Upper Back", equipment: "Cable", isBodyweight: false),
        BevelExercise(id: "incline_curl", name: "Incline Dumbbell Curl", category: "Pull", primaryMuscle: "Biceps", secondaryMuscle: nil, equipment: "Dumbbell", isBodyweight: false),
        BevelExercise(id: "hammer_curl", name: "Dumbbell Hammer Curl", category: "Pull", primaryMuscle: "Biceps", secondaryMuscle: "Forearms", equipment: "Dumbbell", isBodyweight: false),
        BevelExercise(id: "preacher_curl", name: "Preacher EZ-Bar Curl", category: "Pull", primaryMuscle: "Biceps", secondaryMuscle: nil, equipment: "EZ Bar", isBodyweight: false),
        BevelExercise(id: "hanging_leg_raise", name: "Hanging Leg Raises", category: "Core", primaryMuscle: "Core", secondaryMuscle: "Forearms", equipment: "Bodyweight", isBodyweight: true),
        BevelExercise(id: "cable_crunch", name: "Kneeling Cable Crunch", category: "Core", primaryMuscle: "Core", secondaryMuscle: nil, equipment: "Cable", isBodyweight: false),
        BevelExercise(id: "farmers_carry", name: "Heavy Farmer's Carry", category: "Core", primaryMuscle: "Forearms", secondaryMuscle: "Core", equipment: "Dumbbell", isBodyweight: false),
        BevelExercise(id: "zone2_erg", name: "Zone 2 Row / Bike", category: "Conditioning", primaryMuscle: "Cardio", secondaryMuscle: "Quads", equipment: "Ergometer", isBodyweight: true)
    ]
}

public struct StrengthSetItem: Identifiable, Codable, Equatable {
    public let id: UUID
    public var weightKg: Double
    public var reps: Int
    public var rpe: Double
    public var completed: Bool
    public var completedAt: Date?

    public var estimated1RM: Double {
        guard reps > 0 else { return 0 }
        let safeReps = min(36, reps)
        return weightKg * 36.0 / (37.0 - Double(safeReps))
    }

    public init(id: UUID = UUID(), weightKg: Double = 40, reps: Int = 8, rpe: Double = 8.0, completed: Bool = false, completedAt: Date? = nil) {
        self.id = id
        self.weightKg = weightKg
        self.reps = reps
        self.rpe = rpe
        self.completed = completed
        self.completedAt = completedAt
    }
}

public struct ActiveBuilderExercise: Identifiable, Codable, Equatable {
    public let id: UUID
    public let exercise: BevelExercise
    public var sets: [StrengthSetItem]

    public init(id: UUID = UUID(), exercise: BevelExercise, sets: [StrengthSetItem]? = nil) {
        self.id = id
        self.exercise = exercise
        self.sets = sets ?? [
            StrengthSetItem(weightKg: exercise.isBodyweight ? 0 : 40, reps: 10),
            StrengthSetItem(weightKg: exercise.isBodyweight ? 0 : 40, reps: 10),
            StrengthSetItem(weightKg: exercise.isBodyweight ? 0 : 40, reps: 10)
        ]
    }
}

private struct ActiveStrengthDraft: Codable {
    let title: String
    let startedAt: Date
    let exercises: [ActiveBuilderExercise]
}

public struct StrengthTemplate: Identifiable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let exerciseIds: [String]

    public static let presets: [StrengthTemplate] = [
        StrengthTemplate(id: "push", title: "Push Hypertrophy", subtitle: "Chest · Shoulders · Triceps", exerciseIds: ["bench_press", "incline_db", "ohp", "db_lateral", "tricep_pushdown"]),
        StrengthTemplate(id: "pull", title: "Pull & V-Taper", subtitle: "Lats · Upper Back · Biceps", exerciseIds: ["pullups", "barbell_row", "lat_pulldown", "face_pull", "incline_curl"]),
        StrengthTemplate(id: "legs", title: "Lower & Posterior", subtitle: "Quads · Hamstrings · Glutes", exerciseIds: ["barbell_squat", "rdl", "bulgarian_split", "leg_curl", "calf_raise"]),
        StrengthTemplate(id: "upper", title: "Upper Power", subtitle: "Compound Strength & Arms", exerciseIds: ["bench_press", "pullups", "ohp", "chest_supported_row", "hammer_curl"]),
        StrengthTemplate(id: "longevity", title: "Longevity Full Body", subtitle: "Decathlon Hinge, Push, Pull, Grip", exerciseIds: ["barbell_squat", "rdl", "incline_db", "lat_pulldown", "farmers_carry"])
    ]
}

public struct ExerciseBestRecord: Codable {
    public var best1RM: Double
    public var lastWeightKg: Double
    public var lastReps: Int
    public var updatedAt: Date
}

public struct LoggedStrengthWorkout: Identifiable, Codable {
    public let id: UUID
    public let title: String
    public let date: Date
    public let totalVolumeKg: Double
    public let completedSets: Int
    public let totalReps: Int
    public let durationMinutes: Double
    public let calories: Double
    public let muscleSets: [String: Int]
    public var exerciseNames: [String]? = nil
}

@MainActor
public final class StrengthBuilderStore: ObservableObject {
    public static let shared = StrengthBuilderStore()

    @Published public var activeTitle: String = "Custom Session"
    @Published public var activeSessionStart: Date = Date()
    @Published public var activeExercises: [ActiveBuilderExercise] = []
    @Published public var customExercises: [BevelExercise] = []
    @Published public var bestRecords: [String: ExerciseBestRecord] = [:]
    @Published public var completedWorkouts: [LoggedStrengthWorkout] = []

    private let customKey = "apex_strength_custom_ex_v1"
    private let prKey = "apex_strength_prs_v1"
    private let historyKey = "apex_strength_history_v1"
    private let draftKey = "apex_active_strength_draft_v1"

    private init() {
        load()
    }

    public var allExercises: [BevelExercise] {
        customExercises + BevelExercise.library
    }

    public var muscleVolume7Days: [String: Int] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        var totals: [String: Int] = [:]
        for w in completedWorkouts where w.date >= cutoff {
            for (muscle, sets) in w.muscleSets {
                totals[muscle, default: 0] += sets
            }
        }
        return totals
    }

    public var currentSessionVolumeKg: Double {
        let bw = HealthKitManager.shared.bodyWeightKg ?? 75.0
        return activeExercises.reduce(0.0) { sum, item in
            let itemVol = item.sets.filter(\.completed).reduce(0.0) { setSum, set in
                let effWeight = item.exercise.isBodyweight ? bw : max(0.0, set.weightKg)
                return setSum + effWeight * Double(set.reps)
            }
            return sum + itemVol
        }
    }

    public var currentSessionCompletedSets: Int {
        activeExercises.reduce(0) { $0 + $1.sets.filter(\.completed).count }
    }

    public func loadTemplate(_ template: StrengthTemplate, scaleSets: Double = 1.0, loadMultiplier: Double = 1.0) {
        activeTitle = template.title
        activeSessionStart = Date()
        let setCount = max(2, Int((3.0 * scaleSets).rounded()))
        activeExercises = template.exerciseIds.compactMap { id in
            guard let ex = allExercises.first(where: { $0.id == id }) else { return nil }
            let rec = bestRecords[ex.id]
            let rawDefaultWeight = rec?.lastWeightKg ?? (ex.isBodyweight ? 0 : 40)
            let scaledWeight = ex.isBodyweight ? 0 : ((rawDefaultWeight * loadMultiplier / 2.5).rounded() * 2.5)
            let defaultReps = rec?.lastReps ?? 8
            let sets = (0..<setCount).map { _ in
                StrengthSetItem(weightKg: max(ex.isBodyweight ? 0 : 5, scaledWeight), reps: defaultReps)
            }
            return ActiveBuilderExercise(exercise: ex, sets: sets)
        }
        saveDraft()
    }

    public func addExercise(_ exercise: BevelExercise) {
        if activeExercises.isEmpty {
            activeSessionStart = Date()
        }
        let rec = bestRecords[exercise.id]
        let defaultWeight = rec?.lastWeightKg ?? (exercise.isBodyweight ? 0 : 35)
        let defaultReps = rec?.lastReps ?? 10
        let sets = (0..<3).map { _ in StrengthSetItem(weightKg: defaultWeight, reps: defaultReps) }
        activeExercises.append(ActiveBuilderExercise(exercise: exercise, sets: sets))
        saveDraft()
    }

    public func addCustomExercise(name: String, category: String, primaryMuscle: String, equipment: String, isBodyweight: Bool) {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        let ex = BevelExercise(
            id: "custom_\(UUID().uuidString.prefix(8))",
            name: clean,
            category: category,
            primaryMuscle: primaryMuscle,
            secondaryMuscle: nil,
            equipment: equipment,
            isBodyweight: isBodyweight
        )
        customExercises.insert(ex, at: 0)
        if let data = try? JSONEncoder().encode(customExercises) {
            UserDefaults.standard.set(data, forKey: customKey)
        }
        addExercise(ex)
    }

    public func discardActiveSession() {
        activeExercises.removeAll()
        activeTitle = "Custom Session"
        activeSessionStart = Date()
        UserDefaults.standard.removeObject(forKey: draftKey)
    }

    public func deleteCompletedWorkout(id: UUID) {
        completedWorkouts.removeAll { $0.id == id }
        persist()
    }

    public func saveDraft() {
        if activeExercises.isEmpty {
            UserDefaults.standard.removeObject(forKey: draftKey)
            return
        }
        let draft = ActiveStrengthDraft(title: activeTitle, startedAt: activeSessionStart, exercises: activeExercises)
        if let d = try? JSONEncoder().encode(draft) {
            UserDefaults.standard.set(d, forKey: draftKey)
        }
    }

    public func finishSession(health: HealthKitManager, durationMinutes: Double) async -> (prCount: Int, calories: Double) {
        var volume = 0.0
        var totalSets = 0
        var totalReps = 0
        var muscleCounts: [String: Int] = [:]
        var prCount = 0
        var workedExerciseNames: [String] = []

        for item in activeExercises {
            let doneSets = item.sets.filter(\.completed)
            guard !doneSets.isEmpty else { continue }
            workedExerciseNames.append(item.exercise.name)
            totalSets += doneSets.count
            muscleCounts[item.exercise.primaryMuscle, default: 0] += doneSets.count
            if let sec = item.exercise.secondaryMuscle {
                muscleCounts[sec, default: 0] += max(1, doneSets.count / 2)
            }
            for s in doneSets {
                totalReps += s.reps
                let effWeight = item.exercise.isBodyweight ? (health.bodyWeightKg ?? 75.0) : s.weightKg
                volume += effWeight * Double(s.reps)
                if !item.exercise.isBodyweight && s.weightKg > 0 {
                    let est = s.estimated1RM
                    let prev = bestRecords[item.exercise.id]?.best1RM ?? 0
                    if est > prev && prev > 0 { prCount += 1 }
                    if est >= prev {
                        bestRecords[item.exercise.id] = ExerciseBestRecord(
                            best1RM: (est * 10).rounded() / 10,
                            lastWeightKg: s.weightKg,
                            lastReps: s.reps,
                            updatedAt: Date()
                        )
                    } else {
                        bestRecords[item.exercise.id]?.lastWeightKg = s.weightKg
                        bestRecords[item.exercise.id]?.lastReps = s.reps
                    }
                }
            }
        }

        let mins = max(5.0, durationMinutes)
        let kcal = max(35.0, Double(totalSets) * 14.0 + mins * 4.2)

        let entry = LoggedStrengthWorkout(
            id: UUID(),
            title: activeTitle,
            date: Date(),
            totalVolumeKg: volume.rounded(),
            completedSets: totalSets,
            totalReps: totalReps,
            durationMinutes: (mins * 10).rounded() / 10,
            calories: kcal.rounded(),
            muscleSets: muscleCounts,
            exerciseNames: workedExerciseNames
        )
        completedWorkouts.insert(entry, at: 0)
        health.addStrengthStrainBonus(Double(totalSets) * 0.45)
        persist()

        _ = await health.logWorkout(calories: kcal, durationMinutes: mins, workoutType: .traditionalStrengthTraining)
        health.syncEventToMac(extraPayload: [
            "workoutSet": [
                "id": entry.id.uuidString,
                "exercise": entry.title,
                "reps": entry.totalReps,
                "durationSeconds": Int(mins * 60),
                "calories": entry.calories,
                "volumeKg": entry.totalVolumeKg,
                "sets": entry.completedSets,
                "date": ISO8601DateFormatter().string(from: entry.date)
            ],
            "muscleVolumes7d": muscleVolume7Days
        ])
        discardActiveSession()
        return (prCount, kcal)
    }

    public func logExternalWatchSet(exerciseName: String, weightKg: Double, reps: Int, rpe: Double, health: HealthKitManager) {
        let matched = BevelExercise.library.first(where: { $0.name.lowercased() == exerciseName.lowercased() })
            ?? BevelExercise(
                id: "watch_\(exerciseName.lowercased().replacingOccurrences(of: " ", with: "_"))",
                name: exerciseName,
                category: "Strength",
                primaryMuscle: "Full Body",
                secondaryMuscle: nil,
                equipment: "Watch",
                isBodyweight: weightKg <= 0
            )
        let effWeight = weightKg > 0 ? weightKg : (health.bodyWeightKg ?? 75.0)
        let est1RM = ApexBiometricMath.brzycki1RM(weightKg: effWeight, reps: reps)
        let prevBest = bestRecords[matched.id]?.best1RM ?? 0
        if est1RM >= prevBest && weightKg > 0 {
            bestRecords[matched.id] = ExerciseBestRecord(best1RM: est1RM, lastWeightKg: weightKg, lastReps: reps, updatedAt: Date())
        }
        let entry = LoggedStrengthWorkout(
            id: UUID(),
            title: "Watch · \(matched.name)",
            date: Date(),
            totalVolumeKg: (effWeight * Double(reps)).rounded(),
            completedSets: 1,
            totalReps: reps,
            durationMinutes: 3.0,
            calories: 18.0,
            muscleSets: [matched.primaryMuscle: 1],
            exerciseNames: [matched.name]
        )
        completedWorkouts.insert(entry, at: 0)
        health.addStrengthStrainBonus(0.45)
        persist()
        health.syncEventToMac(extraPayload: [
            "workoutSet": [
                "id": entry.id.uuidString,
                "exercise": entry.title,
                "reps": reps,
                "durationSeconds": 180,
                "calories": 18,
                "volumeKg": entry.totalVolumeKg,
                "sets": 1,
                "date": ISO8601DateFormatter().string(from: entry.date)
            ],
            "muscleVolumes7d": muscleVolume7Days
        ])
    }

    public func reloadFromDisk() {
        load()
    }

    private func load() {
        if let d = UserDefaults.standard.data(forKey: customKey),
           let dec = try? JSONDecoder().decode([BevelExercise].self, from: d) {
            customExercises = dec
        }
        if let d = UserDefaults.standard.data(forKey: prKey),
           let dec = try? JSONDecoder().decode([String: ExerciseBestRecord].self, from: d) {
            bestRecords = dec
        }
        if let d = UserDefaults.standard.data(forKey: historyKey),
           let dec = try? JSONDecoder().decode([LoggedStrengthWorkout].self, from: d) {
            completedWorkouts = dec
        }
        if let d = UserDefaults.standard.data(forKey: draftKey),
           let draft = try? JSONDecoder().decode(ActiveStrengthDraft.self, from: d) {
            activeTitle = draft.title
            activeSessionStart = draft.startedAt
            activeExercises = draft.exercises
        }
    }

    private func persist() {
        if let d = try? JSONEncoder().encode(bestRecords) {
            UserDefaults.standard.set(d, forKey: prKey)
        }
        if let d = try? JSONEncoder().encode(Array(completedWorkouts.prefix(40))) {
            UserDefaults.standard.set(d, forKey: historyKey)
        }
    }
}

// MARK: - Bevel Pro Strength Builder UI
public struct StrengthBuilderView: View {
    @ObservedObject private var store = StrengthBuilderStore.shared
    @ObservedObject private var health = HealthKitManager.shared
    @ObservedObject private var activityMgr = WorkoutActivityManager.shared
    @AppStorage(ApexUnitPreferences.unitKey) private var unitSystemRaw: String = ApexUnitSystem.metric.rawValue

    @State private var showExercisePicker = false
    @State private var showOneRMCalculator = false
    @State private var selectedWorkoutDetail: LoggedStrengthWorkout? = nil
    @State private var finishBanner: String? = nil
    @State private var isFinishing = false

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let banner = finishBanner {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(ApexTheme.accentEmerald)
                    Text(banner)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ApexTheme.accentEmerald.opacity(0.16))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            if store.activeExercises.isEmpty {
                templateLauncherCard
            } else {
                activeBuilderHeader
                ForEach($store.activeExercises) { $item in
                    exerciseCard(item: $item)
                }
                activeBuilderActions
            }

            muscularLoadCard

            if !store.completedWorkouts.isEmpty {
                recentWorkoutsCard
            }
        }
        .onChange(of: store.activeExercises) { _, _ in
            store.saveDraft()
        }
        .sheet(isPresented: $showExercisePicker) {
            ExerciseLibraryPickerSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showOneRMCalculator) {
            OneRMCalculatorSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedWorkoutDetail) { workout in
            StrengthWorkoutDetailSheet(workout: workout) {
                store.deleteCompletedWorkout(id: workout.id)
                selectedWorkoutDetail = nil
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    private var templateLauncherCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Strength Builder")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Progressive overload, Brzycki 1RM PRs & muscular load")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 8) {
                    Button {
                        Haptics.tap()
                        showOneRMCalculator = true
                    } label: {
                        Label("1RM", systemImage: "percent")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(ApexTheme.standCyan)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(ApexTheme.elevatedSurface)
                            .clipShape(Capsule())
                    }

                    Button {
                        Haptics.tap(.medium)
                        store.activeSessionStart = Date()
                        store.activeTitle = "Custom Session"
                        showExercisePicker = true
                    } label: {
                        Label("Blank", systemImage: "plus")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(ApexTheme.accentVolt)
                            .clipShape(Capsule())
                    }
                }
            }

            let readinessScale: Double = {
                guard let rdy = health.readinessScore else { return 1.0 }
                return rdy < 55 ? 0.7 : 1.0
            }()

            ForEach(StrengthTemplate.presets) { tpl in
                Button {
                    Haptics.tap(.medium)
                    store.loadTemplate(tpl, scaleSets: readinessScale)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tpl.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                            Text(tpl.subtitle)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(tpl.exerciseIds.count) ex")
                            .font(.system(size: 12, weight: .semibold).monospacedDigit())
                            .foregroundStyle(ApexTheme.standCyan)
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(ApexTheme.accentVolt)
                    }
                    .padding(14)
                    .background(ApexTheme.elevatedSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .appleCard(padding: 18, cornerRadius: 22)
    }

    private var activeBuilderHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(store.activeTitle)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                Text("\(store.currentSessionCompletedSets) sets done · \(ApexUnitPreferences.formatWeight(kg: store.currentSessionVolumeKg)) volume")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(ApexTheme.standCyan)
            }
            Spacer()
            HStack(spacing: 8) {
                Button {
                    Haptics.tap()
                    showOneRMCalculator = true
                } label: {
                    Image(systemName: "percent")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ApexTheme.standCyan)
                        .padding(9)
                        .background(ApexTheme.elevatedSurface)
                        .clipShape(Circle())
                }
                Button {
                    Haptics.tap()
                    showExercisePicker = true
                } label: {
                    Label("Exercise", systemImage: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(ApexTheme.accentVolt)
                        .clipShape(Capsule())
                }
            }
        }
        .appleCard(padding: 16, cornerRadius: 20)
    }

    private func exerciseCard(item: Binding<ActiveBuilderExercise>) -> some View {
        let wrapped = item.wrappedValue
        let prevRecord = store.bestRecords[wrapped.exercise.id]
        let bestDone1RM = wrapped.sets.filter(\.completed).map(\.estimated1RM).max() ?? 0
        let hitNewPR = !wrapped.exercise.isBodyweight && prevRecord != nil && bestDone1RM > (prevRecord?.best1RM ?? 0)
        let weightUnit = ApexUnitPreferences.weightUnitLabel

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(wrapped.exercise.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                        if hitNewPR {
                            Text("PR")
                                .font(.system(size: 10, weight: .black))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(ApexTheme.accentVolt)
                                .clipShape(Capsule())
                        }
                    }
                    Text("\(wrapped.exercise.primaryMuscle) · \(wrapped.exercise.equipment)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let rec = prevRecord {
                    Text("Best 1RM \(ApexUnitPreferences.formatWeight(kg: rec.best1RM))")
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(ApexTheme.standCyan)
                }
            }

            ForEach(Array(item.sets.indices), id: \.self) { idx in
                let isDone = item.sets[idx].wrappedValue.completed
                let weightBinding = Binding<Double>(
                    get: {
                        let v = ApexUnitPreferences.weightValue(kg: item.sets[idx].weightKg.wrappedValue)
                        return (v * 10).rounded() / 10
                    },
                    set: { displayed in
                        item.sets[idx].weightKg.wrappedValue = max(0, ApexUnitPreferences.kgFromWeightInput(displayed))
                    }
                )
                HStack(spacing: 6) {
                    Text("\(idx + 1)")
                        .font(.system(size: 13, weight: .bold).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 18)

                    if !wrapped.exercise.isBodyweight {
                        HStack(spacing: 2) {
                            TextField("0", value: weightBinding, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.center)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .frame(width: 50, height: 34)
                                .background(ApexTheme.elevatedSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            Text(weightUnit)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("BW")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 64)
                    }

                    HStack(spacing: 2) {
                        TextField("0", value: item.sets[idx].reps, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .frame(width: 42, height: 34)
                            .background(ApexTheme.elevatedSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        Text("reps")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }

                    Menu {
                        ForEach([6.0, 6.5, 7.0, 7.5, 8.0, 8.5, 9.0, 9.5, 10.0], id: \.self) { val in
                            Button(String(format: "RPE %.1f", val)) {
                                Haptics.selection()
                                item.sets[idx].rpe.wrappedValue = val
                            }
                        }
                    } label: {
                        Text(String(format: "RPE %.1g", item.sets[idx].rpe.wrappedValue))
                            .font(.system(size: 11, weight: .semibold).monospacedDigit())
                            .foregroundStyle(ApexTheme.accentAmber)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(ApexTheme.elevatedSurface)
                            .clipShape(Capsule())
                    }

                    Spacer()

                    Button {
                        Haptics.tap(.medium)
                        item.sets[idx].completed.wrappedValue.toggle()
                        if item.sets[idx].completed.wrappedValue {
                            item.sets[idx].completedAt.wrappedValue = Date()
                            if !activityMgr.isLiveActivityActive {
                                activityMgr.startSet(exercise: wrapped.exercise.name)
                            }
                            activityMgr.startRestCountdown(
                                seconds: 90,
                                reps: item.sets[idx].reps.wrappedValue,
                                elapsedSeconds: Int(Date().timeIntervalSince(store.activeSessionStart))
                            )
                        }
                    } label: {
                        Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 24))
                            .foregroundStyle(isDone ? ApexTheme.exerciseLime : .secondary)
                    }
                    .frame(minWidth: 40, minHeight: 40)
                }
            }

            HStack(spacing: 12) {
                Button {
                    Haptics.tap()
                    let last = item.sets.wrappedValue.last ?? StrengthSetItem(weightKg: 40, reps: 10)
                    item.sets.wrappedValue.append(StrengthSetItem(weightKg: last.weightKg, reps: last.reps, rpe: last.rpe))
                } label: {
                    Label("Add Set", systemImage: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ApexTheme.standCyan)
                }
                if item.sets.wrappedValue.count > 1 {
                    Button {
                        Haptics.tap()
                        _ = item.sets.wrappedValue.popLast()
                    } label: {
                        Label("Del Set", systemImage: "minus")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button {
                    Haptics.tap()
                    store.activeExercises.removeAll { $0.id == wrapped.id }
                } label: {
                    Text("Remove")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 2)
        }
        .appleCard(padding: 16, cornerRadius: 20)
    }

    private var activeBuilderActions: some View {
        HStack(spacing: 12) {
            Button {
                Haptics.tap()
                activityMgr.endSet()
                store.discardActiveSession()
            } label: {
                Text("Discard")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(ApexTheme.elevatedSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            Button {
                isFinishing = true
                Task {
                    let mins = max(5.0, Date().timeIntervalSince(store.activeSessionStart) / 60.0)
                    let res = await store.finishSession(health: health, durationMinutes: mins)
                    activityMgr.endSet()
                    isFinishing = false
                    Haptics.success()
                    finishBanner = res.prCount > 0
                        ? "Saved to Health · \(Int(res.calories)) kcal · \(res.prCount) New 1RM PR!"
                        : "Workout saved to Apple Health · \(Int(res.calories)) kcal"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { finishBanner = nil }
                }
            } label: {
                HStack(spacing: 6) {
                    if isFinishing { ProgressView().tint(.black) }
                    Text(isFinishing ? "Saving..." : "Finish & Save")
                }
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(ApexTheme.exerciseLime)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .disabled(isFinishing || store.currentSessionCompletedSets == 0)
            .opacity(store.currentSessionCompletedSets == 0 ? 0.5 : 1.0)
        }
    }

    private var muscularLoadCard: some View {
        let vol = store.muscleVolume7Days
        let trackedMuscles = ["Chest", "Upper Back", "Lats", "Shoulders", "Quads", "Hamstrings", "Glutes", "Biceps", "Triceps", "Forearms", "Core", "Calves", "Cardio", "Full Body"]

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("7-Day Muscular Load")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(vol.isEmpty ? "Complete strength sets to map weekly tissue load" : "\(vol.values.reduce(0, +)) working sets logged across muscle groups")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "figure.strengthtraining.traditional")
                    .foregroundStyle(ApexTheme.moveCrimson)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(trackedMuscles, id: \.self) { m in
                    let sets = vol[m] ?? 0
                    let target = 12.0
                    let pct = min(1.0, Double(sets) / target)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(m)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white)
                            Spacer()
                            Text("\(sets) sets")
                                .font(.system(size: 11, weight: .bold).monospacedDigit())
                                .foregroundStyle(sets > 0 ? ApexTheme.standCyan : .secondary)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(ApexTheme.elevatedSurface)
                                Capsule()
                                    .fill(sets >= 14 ? ApexTheme.accentAmber : ApexTheme.exerciseLime)
                                    .frame(width: geo.size.width * CGFloat(pct))
                            }
                        }
                        .frame(height: 5)
                    }
                    .padding(10)
                    .background(ApexTheme.background.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .appleCard(padding: 18, cornerRadius: 22)
    }

    private var recentWorkoutsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Strength Logbook")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
            ForEach(store.completedWorkouts.prefix(8)) { w in
                Button {
                    Haptics.tap()
                    selectedWorkoutDetail = w
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(w.title)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                            Text("\(w.completedSets) sets · \(w.totalReps) reps · \(ApexUnitPreferences.formatWeight(kg: w.totalVolumeKg))")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(Int(w.calories)) kcal")
                                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                                .foregroundStyle(ApexTheme.moveCrimson)
                            Text(w.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .appleCard(padding: 14, cornerRadius: 16)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Searchable Exercise Library Picker + Custom Exercise Sheet
private struct ExerciseLibraryPickerSheet: View {
    @ObservedObject private var store = StrengthBuilderStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var query: String = ""
    @State private var selectedCat: String = "All"
    @State private var showCustomForm = false
    @State private var customName = ""
    @State private var customCategory = "Push"
    @State private var customMuscle = "Chest"
    @State private var customEquip = "Dumbbell"
    @State private var customIsBodyweight = false

    private let categories = ["All", "Push", "Pull", "Legs", "Core", "Conditioning"]
    private let formCategories = ["Push", "Pull", "Legs", "Core", "Conditioning"]
    private let muscles = ["Chest", "Upper Back", "Lats", "Shoulders", "Quads", "Hamstrings", "Glutes", "Biceps", "Triceps", "Forearms", "Core", "Calves", "Cardio", "Full Body"]

    var filtered: [BevelExercise] {
        store.allExercises.filter { ex in
            let catOk = selectedCat == "All" || ex.category == selectedCat
            let qOk = query.isEmpty || ex.name.localizedCaseInsensitiveContains(query) || ex.primaryMuscle.localizedCaseInsensitiveContains(query)
            return catOk && qOk
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if showCustomForm {
                    Section("Create Custom Exercise") {
                        TextField("Exercise Name", text: $customName)
                        Picker("Category", selection: $customCategory) {
                            ForEach(formCategories, id: \.self) { Text($0) }
                        }
                        Picker("Primary Muscle", selection: $customMuscle) {
                            ForEach(muscles, id: \.self) { Text($0) }
                        }
                        TextField("Equipment", text: $customEquip)
                        Toggle("Bodyweight Movement", isOn: $customIsBodyweight)
                        Button("Save & Add to Workout") {
                            store.addCustomExercise(
                                name: customName,
                                category: customCategory,
                                primaryMuscle: customMuscle,
                                equipment: customIsBodyweight ? "Bodyweight" : customEquip,
                                isBodyweight: customIsBodyweight
                            )
                            customName = ""
                            showCustomForm = false
                            dismiss()
                        }
                        .disabled(customName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(categories, id: \.self) { cat in
                                Button {
                                    selectedCat = cat
                                } label: {
                                    Text(cat)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(selectedCat == cat ? .black : .white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(selectedCat == cat ? ApexTheme.accentVolt : ApexTheme.elevatedSurface)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                }

                ForEach(filtered) { ex in
                    Button {
                        Haptics.tap()
                        store.addExercise(ex)
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ex.name)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                                Text("\(ex.primaryMuscle) · \(ex.equipment)")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(ApexTheme.accentVolt)
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "Search exercises or muscles")
            .navigationTitle("Exercise Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(showCustomForm ? "Cancel" : "Custom") { showCustomForm.toggle() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Brzycki / Epley 1RM & Training Zone Calculator Sheet
private struct OneRMCalculatorSheet: View {
    @AppStorage(ApexUnitPreferences.unitKey) private var unitRaw: String = ApexUnitSystem.metric.rawValue
    @Environment(\.dismiss) private var dismiss
    @State private var inputWeightKg: Double = 80.0
    @State private var reps: Int = 5

    private var brzyckiKg: Double {
        ApexBiometricMath.brzycki1RM(weightKg: inputWeightKg, reps: reps)
    }

    private var epleyKg: Double {
        guard inputWeightKg > 0, reps > 0 else { return 0 }
        return reps == 1 ? inputWeightKg : (inputWeightKg * (1.0 + Double(reps) / 30.0))
    }

    var body: some View {
        let _ = unitRaw
        let unitLabel = ApexUnitPreferences.weightUnitLabel
        let weightBinding = Binding<Double>(
            get: { (ApexUnitPreferences.weightValue(kg: inputWeightKg) * 10).rounded() / 10 },
            set: { inputWeightKg = max(5, min(400, ApexUnitPreferences.kgFromWeightInput($0))) }
        )

        return NavigationStack {
            List {
                Section("Working Set Input") {
                    HStack {
                        Text("Load (\(unitLabel))")
                        Spacer()
                        TextField("80", value: weightBinding, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                    }
                    Stepper("Reps Completed: \(reps)", value: $reps, in: 1...20)
                }

                Section("Estimated 1-Rep Max") {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Brzycki 1RM")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Validated for 1–12 rep sets")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(ApexUnitPreferences.formatWeight(kg: brzyckiKg))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(ApexTheme.accentVolt)
                    }
                    HStack {
                        Text("Epley 1RM")
                            .font(.system(size: 14, weight: .semibold))
                        Spacer()
                        Text(ApexUnitPreferences.formatWeight(kg: epleyKg))
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(ApexTheme.standCyan)
                    }
                }

                Section("Percentage Load Zones (Brzycki)") {
                    ForEach([(95, "Peaking · 1–2 reps"), (90, "Max Strength · 2–4 reps"), (85, "Strength · 4–6 reps"), (80, "Power Hypertrophy · 6–8 reps"), (75, "Hypertrophy · 8–10 reps"), (70, "Metabolic · 10–12 reps"), (60, "Speed / VBT · 0.8–1.0 m/s")], id: \.0) { pct, desc in
                        let zoneKg = brzyckiKg * Double(pct) / 100.0
                        HStack {
                            Text("\(pct)%")
                                .font(.system(size: 14, weight: .bold).monospacedDigit())
                                .foregroundStyle(ApexTheme.accentAmber)
                                .frame(width: 44, alignment: .leading)
                            Text(desc)
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(ApexUnitPreferences.formatWeight(kg: zoneKg))
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .monospacedDigit()
                        }
                    }
                }
            }
            .navigationTitle("1RM & Zone Calculator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Strength Workout Logbook Inspector Sheet
private struct StrengthWorkoutDetailSheet: View {
    let workout: LoggedStrengthWorkout
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Summary") {
                    LabeledContent("Date", value: workout.date.formatted(date: .abbreviated, time: .shortened))
                    LabeledContent("Volume", value: ApexUnitPreferences.formatWeight(kg: workout.totalVolumeKg))
                    LabeledContent("Sets / Reps", value: "\(workout.completedSets) sets · \(workout.totalReps) reps")
                    LabeledContent("Duration", value: String(format: "%.0f min", workout.durationMinutes))
                    LabeledContent("Energy Burned", value: "\(Int(workout.calories)) kcal")
                }

                if let names = workout.exerciseNames, !names.isEmpty {
                    Section("Exercises Completed") {
                        ForEach(names, id: \.self) { Text($0) }
                    }
                }

                if !workout.muscleSets.isEmpty {
                    Section("Muscle Groups Targeted") {
                        ForEach(workout.muscleSets.sorted(by: { $0.value > $1.value }), id: \.key) { muscle, sets in
                            LabeledContent(muscle, value: "\(sets) sets")
                        }
                    }
                }

                Section {
                    Button("Delete Workout Entry", role: .destructive) {
                        onDelete()
                        dismiss()
                    }
                }
            }
            .navigationTitle(workout.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Bevel Adaptive Multi-Week Training Plan View
public struct AdaptiveTrainingPlanView: View {
    @ObservedObject private var health = HealthKitManager.shared
    @ObservedObject private var builder = StrengthBuilderStore.shared
    @ObservedObject private var watchScheduler = WatchWorkoutScheduler.shared

    @AppStorage("apex_training_goal_v1") private var selectedGoal: String = "Hybrid Longevity"
    @AppStorage("apex_training_week_v1") private var currentWeek: Int = 1

    private let goals = ["Hybrid Longevity", "Hypertrophy Focus", "Strength & VBT", "VO₂ Max Engine"]

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Adaptive 4-Week Plan")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                        Text("Week \(currentWeek) of 4 · Scales sets & load to live Readiness")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Stepper("", value: $currentWeek, in: 1...4)
                        .labelsHidden()
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(goals, id: \.self) { g in
                            Button {
                                Haptics.tap()
                                selectedGoal = g
                            } label: {
                                Text(g)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(selectedGoal == g ? .black : .white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(selectedGoal == g ? ApexTheme.accentVolt : ApexTheme.elevatedSurface)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .appleCard(padding: 18, cornerRadius: 22)

            readinessAdaptationBanner

            VStack(alignment: .leading, spacing: 10) {
                Text("Weekly Prescription")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)

                ForEach(weeklySchedule, id: \.day) { item in
                    HStack(spacing: 12) {
                        Text(item.day)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(item.isToday ? .black : .secondary)
                            .frame(width: 40, height: 32)
                            .background(item.isToday ? ApexTheme.accentVolt : ApexTheme.elevatedSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.session)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                            Text(item.prescription)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if item.isToday, let tpl = item.template {
                            Button {
                                Haptics.tap(.medium)
                                builder.loadTemplate(tpl, scaleSets: recoveryScaleFactor, loadMultiplier: weekLoadMultiplier)
                                ApexNavigationRouter.shared.requestedTrainSegment = 0
                            } label: {
                                Text("Load")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(ApexTheme.exerciseLime)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .appleCard(padding: 14, cornerRadius: 16)
                }
            }

            Button {
                Task {
                    await watchScheduler.pushStrengthProtocolToWatch(
                        title: "\(selectedGoal) Wk\(currentWeek)",
                        durationMinutes: 40,
                        activity: selectedGoal == "VO₂ Max Engine" ? .running : .traditionalStrengthTraining
                    )
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "applewatch.radiowaves.left.and.right")
                        .foregroundStyle(ApexTheme.exerciseLime)
                    Text(watchScheduler.statusMessage ?? "Schedule Plan on Apple Watch")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                }
                .appleCard(padding: 16, cornerRadius: 18)
            }
            .buttonStyle(.plain)
        }
    }

    private var weekLoadMultiplier: Double {
        switch currentWeek {
        case 1: return 1.0
        case 2: return 1.025
        case 3: return 1.05
        default: return 0.85 // Week 4 deload intensity
        }
    }

    private var recoveryScaleFactor: Double {
        if let delta = health.hrvDeltaPercent, delta <= -15 { return 0.65 }
        if let rdy = health.readinessScore, rdy < 58 { return 0.7 }
        if currentWeek == 4 { return 0.6 } // Week 4 Deload
        return 1.0
    }

    private var readinessAdaptationBanner: some View {
        let title: String
        let detail: String
        let tint: Color

        if let rdy = health.readinessScore {
            if rdy >= 78 && currentWeek < 4 {
                title = "Autonomic Green Light · \(rdy)% Readiness"
                detail = "Prescribing full Week \(currentWeek) progressive overload (+\(Int((weekLoadMultiplier - 1.0) * 100))% load / 2 RIR)."
                tint = ApexTheme.accentEmerald
            } else if currentWeek == 4 {
                title = "Deload Week 4 · Recovery Supercompensation"
                detail = "Volume tapered by 40% and load trimmed 15% to preserve bar velocity."
                tint = ApexTheme.standCyan
            } else {
                title = "Autonomic Guardrail · \(rdy)% Readiness"
                detail = "Trimming working sets by 30% today and prioritizing Zone 2 / tempo recovery."
                tint = ApexTheme.accentAmber
            }
        } else {
            title = "Connect Apple Health to Auto-Scale Load"
            detail = "Pair HealthKit so your daily recovery, HRV delta, and strain dynamically adjust set volume."
            tint = ApexTheme.accentIndigo
        }

        return HStack(spacing: 12) {
            Circle().fill(tint).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .appleCard(padding: 16, cornerRadius: 18)
    }

    private var weeklySchedule: [(day: String, session: String, prescription: String, isToday: Bool, template: StrengthTemplate?)] {
        let weekdayIdx = (Calendar.current.component(.weekday, from: Date()) + 5) % 7 // Mon = 0 ... Sun = 6
        let push = StrengthTemplate.presets[0]
        let pull = StrengthTemplate.presets[1]
        let legs = StrengthTemplate.presets[2]
        let upper = StrengthTemplate.presets[3]
        let full = StrengthTemplate.presets[4]
        let setHint = currentWeek == 4 ? "2 sets · RPE 6 (-15% load)" : "\(2 + min(2, currentWeek - 1))–4 sets · RPE \(7 + min(2, currentWeek - 1))"

        let base: [(String, String, String, StrengthTemplate?)] = {
            switch selectedGoal {
            case "Hypertrophy Focus":
                return [
                    ("Mon", "Push Hypertrophy", setHint, push),
                    ("Tue", "Pull & V-Taper", setHint, pull),
                    ("Wed", "Zone 2 Flush + Core", "35 min @ 130–142 bpm", nil),
                    ("Thu", "Lower & Posterior", setHint, legs),
                    ("Fri", "Upper Power", setHint, upper),
                    ("Sat", "Longevity Full Body", setHint, full),
                    ("Sun", "Active Rest & Sunlight", "8,000+ steps nasal", nil)
                ]
            case "Strength & VBT":
                return [
                    ("Mon", "Heavy Lower & Squat VBT", "\(setHint) · Stop @ 15% VBT loss", legs),
                    ("Tue", "Upper Power & Bench VBT", "\(setHint) · 0.55–0.75 m/s target", upper),
                    ("Wed", "Zone 2 Flush + Dead Hang", "30 min aerobic + grip endurance", nil),
                    ("Thu", "Pull & Posterior Hinge", "\(setHint) · Explosive concentric", pull),
                    ("Fri", "Push Overhead & Speed", "\(setHint) · 0.80 m/s dynamic effort", push),
                    ("Sat", "Longevity Full Body Power", setHint, full),
                    ("Sun", "Active Rest & Mobility", "Breathwork + sunlight walk", nil)
                ]
            case "VO₂ Max Engine":
                return [
                    ("Mon", "Zone 2 Aerobic Base", "45 min nasal steady", nil),
                    ("Tue", "Longevity Full Body", setHint, full),
                    ("Wed", "4×4 Norwegian Intervals", "4 min @ 90% HRmax / 3m rest", nil),
                    ("Thu", "Recovery Mobility + Hang", "25 min mobility + 2m hang", nil),
                    ("Fri", "Upper Power", setHint, upper),
                    ("Sat", "Zone 2 Long Endurance", "60 min trail / erg", nil),
                    ("Sun", "Parasympathetic Reset", "Breathwork + walk", nil)
                ]
            default:
                return [
                    ("Mon", "Upper Power", setHint, upper),
                    ("Tue", "Zone 2 + Dead Hang", "40 min aerobic + grip", nil),
                    ("Wed", "Lower & Posterior", setHint, legs),
                    ("Thu", "Restorative Mobility", "Posture & breathwork", nil),
                    ("Fri", "Push Hypertrophy", setHint, push),
                    ("Sat", "Pull & VO₂ Intervals", "Pull + 4×4 conditioning", pull),
                    ("Sun", "Sun + Steps Recovery", "9,000 steps outdoor", nil)
                ]
            }
        }()

        return base.enumerated().map { idx, row in
            (row.0, row.1, row.2, idx == weekdayIdx, row.3)
        }
    }
}
