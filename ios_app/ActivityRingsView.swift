import SwiftUI

// MARK: - Artisanal Apple Watch Concentric Activity Rings
public struct ActivityRingsView: View {
    public var moveCurrent: Double
    public var moveTarget: Double
    public var exerciseCurrent: Double
    public var exerciseTarget: Double
    public var standCurrent: Double
    public var standTarget: Double
    public var size: CGFloat

    public init(
        moveCurrent: Double,
        moveTarget: Double,
        exerciseCurrent: Double,
        exerciseTarget: Double,
        standCurrent: Double,
        standTarget: Double,
        size: CGFloat = 148
    ) {
        self.moveCurrent = moveCurrent
        self.moveTarget = max(moveTarget, 1)
        self.exerciseCurrent = exerciseCurrent
        self.exerciseTarget = max(exerciseTarget, 1)
        self.standCurrent = standCurrent
        self.standTarget = max(standTarget, 1)
        self.size = size
    }

    private var ringThickness: CGFloat { size * 0.105 }

    private var moveProgress: Double { max(0, min(moveCurrent / moveTarget, 2.0)) }
    private var exerciseProgress: Double { max(0, min(exerciseCurrent / exerciseTarget, 2.0)) }
    private var standProgress: Double { max(0, min(standCurrent / standTarget, 2.0)) }

    public var body: some View {
        ZStack {
            // Outer: Move (Crimson)
            SingleAppleRing(
                diameter: size - ringThickness,
                thickness: ringThickness,
                progress: moveProgress,
                startColor: Color(red: 1.0, green: 0.18, blue: 0.36),
                endColor: ApexTheme.moveCrimson
            )

            // Middle: Exercise (Electric Lime)
            SingleAppleRing(
                diameter: (size - ringThickness) * 0.74,
                thickness: ringThickness,
                progress: exerciseProgress,
                startColor: Color(red: 0.70, green: 1.0, blue: 0.25),
                endColor: ApexTheme.exerciseLime
            )

            // Inner: Stand (Arctic Cyan)
            SingleAppleRing(
                diameter: (size - ringThickness) * 0.48,
                thickness: ringThickness,
                progress: standProgress,
                startColor: Color(red: 0.12, green: 0.92, blue: 1.0),
                endColor: ApexTheme.standCyan
            )
        }
        .frame(width: size, height: size)
        .animation(.spring(response: 0.85, dampingFraction: 0.82), value: moveProgress)
        .animation(.spring(response: 0.85, dampingFraction: 0.82), value: exerciseProgress)
        .animation(.spring(response: 0.85, dampingFraction: 0.82), value: standProgress)
    }
}

private struct SingleAppleRing: View {
    let diameter: CGFloat
    let thickness: CGFloat
    let progress: Double
    let startColor: Color
    let endColor: Color

    var body: some View {
        let clampedProgress = min(progress, 1.0)
        let tipAngle = Angle.degrees(progress * 360.0 - 90.0)
        let radius = diameter / 2.0

        ZStack {
            // Subtle Recessed Track
            Circle()
                .stroke(endColor.opacity(0.16), lineWidth: thickness)
                .frame(width: diameter, height: diameter)

            // Primary Progress Arc
            if progress > 0.005 {
                Circle()
                    .trim(from: 0, to: CGFloat(clampedProgress))
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [startColor, endColor]),
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360)
                        ),
                        style: StrokeStyle(lineWidth: thickness, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: diameter, height: diameter)

                // Signature Apple Ring Overlap Shadow Tip (> 100% OR Leading Edge Highlight)
                Circle()
                    .fill(endColor)
                    .frame(width: thickness, height: thickness)
                    .shadow(color: Color.black.opacity(0.45), radius: 2.5, x: 0, y: 1)
                    .offset(
                        x: radius * CGFloat(cos(tipAngle.radians)),
                        y: radius * CGFloat(sin(tipAngle.radians))
                    )
            }
        }
    }
}
