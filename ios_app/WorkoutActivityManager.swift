import Foundation
import SwiftUI
import Combine
import ActivityKit

// MARK: - ActivityKit Dynamic Island + Rest Countdown Coordinator
@MainActor
public final class WorkoutActivityManager: ObservableObject {
    public static let shared = WorkoutActivityManager()

    @Published public var isLiveActivityActive: Bool = false
    @Published public var restSecondsRemaining: Int = 0
    @Published public var restDurationTarget: Int = 90
    @Published public var isRestTimerRunning: Bool = false

    private var activeExerciseName: String = "Workout"
    private var lastReps: Int = 0
    private var lastElapsed: Int = 0
    private var lastVelocity: Double = 0
    private var lastVelocityDrop: Int = 0

    // Store type-erased Activity reference for iOS 16.1+ availability safety
    private var currentActivityStorage: Any? = nil
    private let restTicker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private var restCancellable: AnyCancellable?

    private init() {
        restCancellable = restTicker.sink { [weak self] _ in
            self?.tickRestTimer()
        }
    }

    public func startSet(exercise: String) {
        activeExerciseName = exercise
        isRestTimerRunning = false
        restSecondsRemaining = 0

        guard #available(iOS 16.1, *) else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        Task {
            await endAllActivities()
            let attributes = ApexWorkoutAttributes(exerciseName: exercise, startedAt: Date())
            let state = ApexWorkoutAttributes.ContentState(
                reps: 0,
                elapsedSeconds: 0,
                restSecondsRemaining: 0,
                isResting: false,
                lastVelocity: 0,
                velocityDropPercent: 0
            )
            do {
                let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(60 * 30))
                let activity = try Activity.request(attributes: attributes, content: content, pushType: nil)
                self.currentActivityStorage = activity
                self.isLiveActivityActive = true
            } catch {
                self.isLiveActivityActive = false
            }
        }
    }

    public func updateSet(reps: Int, elapsedSeconds: Int, velocity: Double, velocityDropPercent: Int) {
        lastReps = reps
        lastElapsed = elapsedSeconds
        lastVelocity = velocity
        lastVelocityDrop = velocityDropPercent
        pushUpdate(isResting: false)
    }

    public func startRestCountdown(seconds: Int = 90, reps: Int, elapsedSeconds: Int) {
        if !isLiveActivityActive {
            startSet(exercise: activeExerciseName)
        }
        restDurationTarget = seconds
        restSecondsRemaining = seconds
        isRestTimerRunning = true
        lastReps = reps
        lastElapsed = elapsedSeconds
        pushUpdate(isResting: true)
    }

    public func stopRestTimer(endActivity: Bool = false) {
        isRestTimerRunning = false
        restSecondsRemaining = 0
        if endActivity {
            Task { await endAllActivities() }
        } else {
            pushUpdate(isResting: false)
        }
    }

    public func endSet() {
        isRestTimerRunning = false
        restSecondsRemaining = 0
        Task {
            await endAllActivities()
        }
    }

    private func tickRestTimer() {
        guard isRestTimerRunning else { return }
        if restSecondsRemaining > 1 {
            restSecondsRemaining -= 1
            if restSecondsRemaining % 5 == 0 || restSecondsRemaining <= 5 {
                pushUpdate(isResting: true)
            }
        } else {
            restSecondsRemaining = 0
            isRestTimerRunning = false
            Haptics.success()
            pushUpdate(isResting: false)
        }
    }

    private func pushUpdate(isResting: Bool) {
        guard #available(iOS 16.1, *),
              let activity = currentActivityStorage as? Activity<ApexWorkoutAttributes> else {
            return
        }
        let state = ApexWorkoutAttributes.ContentState(
            reps: lastReps,
            elapsedSeconds: lastElapsed,
            restSecondsRemaining: restSecondsRemaining,
            isResting: isResting,
            lastVelocity: lastVelocity,
            velocityDropPercent: lastVelocityDrop
        )
        Task {
            let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(60 * 15))
            await activity.update(content)
        }
    }

    @available(iOS 16.1, *)
    private func endAllActivities() async {
        for activity in Activity<ApexWorkoutAttributes>.activities {
            let finalState = ApexWorkoutAttributes.ContentState(
                reps: lastReps,
                elapsedSeconds: lastElapsed,
                restSecondsRemaining: 0,
                isResting: false,
                lastVelocity: lastVelocity,
                velocityDropPercent: lastVelocityDrop
            )
            let content = ActivityContent(state: finalState, staleDate: nil)
            await activity.end(content, dismissalPolicy: .immediate)
        }
        currentActivityStorage = nil
        isLiveActivityActive = false
    }
}
