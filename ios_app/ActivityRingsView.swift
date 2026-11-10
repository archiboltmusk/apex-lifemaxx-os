import SwiftUI

// MARK: - Native SwiftUI Concentric Apple Activity Rings
public struct ActivityRingsView: View {
    public var moveCurrent: Double
    public var moveTarget: Double
    public var exerciseCurrent: Double
    public var exerciseTarget: Double
    public var standCurrent: Double
    public var standTarget: Double
    public var size: CGFloat = 180

    public init(
        moveCurrent: Double,
        moveTarget: Double,
        exerciseCurrent: Double,
        exerciseTarget: Double,
        standCurrent: Double,
        standTarget: Double,
        size: CGFloat = 180
    ) {
        self.moveCurrent = moveCurrent
        self.moveTarget = max(moveTarget, 1)
        self.exerciseCurrent = exerciseCurrent
        self.exerciseTarget = max(exerciseTarget, 1)
        self.standCurrent = standCurrent
        self.standTarget = max(standTarget, 1)
        self.size = size
    }

    private var moveProgress: Double {
        min(moveCurrent / moveTarget, 2.0)
    }

    private var exerciseProgress: Double {
        min(exerciseCurrent / exerciseTarget, 2.0)
    }

    private var standProgress: Double {
        min(standCurrent / standTarget, 2.0)
    }

    public var body: some View {
        ZStack {
            // Background Tracks
            RingTrack(size: size, strokeWidth: size * 0.10, color: Color(red: 0.98, green: 0.07, blue: 0.31).opacity(0.18))
            RingTrack(size: size * 0.78, strokeWidth: size * 0.10, color: Color(red: 0.57, green: 0.91, blue: 0.16).opacity(0.18))
            RingTrack(size: size * 0.56, strokeWidth: size * 0.10, color: Color(red: 0.0, green: 0.84, blue: 0.90).opacity(0.18))

            // 1. Move Ring (Red: Active Calories)
            RingProgress(
                size: size,
                strokeWidth: size * 0.10,
                progress: moveProgress,
                gradient: Gradient(colors: [
                    Color(red: 1.0, green: 0.22, blue: 0.38),
                    Color(red: 0.98, green: 0.07, blue: 0.31)
                ])
            )

            // 2. Exercise Ring (Green: Active Minutes)
            RingProgress(
                size: size * 0.78,
                strokeWidth: size * 0.10,
                progress: exerciseProgress,
                gradient: Gradient(colors: [
                    Color(red: 0.72, green: 0.98, blue: 0.25),
                    Color(red: 0.57, green: 0.91, blue: 0.16)
                ])
            )

            // 3. Stand Ring (Blue/Cyan: Active Stand Hours)
            RingProgress(
                size: size * 0.56,
                strokeWidth: size * 0.10,
                progress: standProgress,
                gradient: Gradient(colors: [
                    Color(red: 0.0, green: 0.94, blue: 1.0),
                    Color(red: 0.0, green: 0.75, blue: 0.85)
                ])
            )
        }
        .frame(width: size, height: size)
    }
}

// Single Ring Track Background
struct RingTrack: View {
    var size: CGFloat
    var strokeWidth: CGFloat
    var color: Color

    var body: some View {
        Circle()
            .stroke(color, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
            .frame(width: size, height: size)
    }
}

// Single Ring Progress Arc with Specular Glow & Rounded Caps
struct RingProgress: View {
    var size: CGFloat
    var strokeWidth: CGFloat
    var progress: Double
    var gradient: Gradient

    var body: some View {
        Circle()
            .trim(from: 0, to: CGFloat(min(progress, 1.0)))
            .stroke(
                AngularGradient(gradient: gradient, center: .center, startAngle: .degrees(-90), endAngle: .degrees(270)),
                style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))
            .frame(width: size, height: size)
            .shadow(color: gradient.stops.first?.color.opacity(0.35) ?? .clear, radius: 6, x: 0, y: 0)
    }
}
