import SwiftUI
import UIKit

// MARK: - Apple Human Interface Design System for APEX OS
public enum ApexTheme {
    // Pure OLED & Grouped Apple Dark Surfaces
    public static let background = Color.black
    public static let cardSurface = Color(red: 0.11, green: 0.11, blue: 0.118)       // #1C1C1E
    public static let elevatedSurface = Color(red: 0.173, green: 0.173, blue: 0.18) // #2C2C2E
    public static let subtleBorder = Color.white.opacity(0.08)

    // Signature Apple Watch & Biometric Colors
    public static let moveCrimson = Color(red: 0.98, green: 0.07, blue: 0.31)       // #FA114F
    public static let exerciseLime = Color(red: 0.58, green: 0.98, blue: 0.16)      // #94FA29
    public static let standCyan = Color(red: 0.00, green: 0.84, blue: 0.96)         // #00D6F5

    // Surgical Performance Accents (Restrained, never noisy)
    public static let accentVolt = Color(red: 0.90, green: 0.99, blue: 0.25)        // #E5FE40
    public static let accentEmerald = Color(red: 0.19, green: 0.82, blue: 0.35)     // #30D158
    public static let accentIndigo = Color(red: 0.37, green: 0.36, blue: 0.90)      // #5E5CE6
    public static let accentAmber = Color(red: 1.00, green: 0.62, blue: 0.04)       // #FF9F0A
}

// MARK: - Apple Taptic Feedback Engine
public enum Haptics {
    public static func tap(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    public static func shutter() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred(intensity: 0.85)
    }

    public static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

    public static func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
    }
}

// MARK: - Native Apple Card Container Modifier
public struct AppleCardModifier: ViewModifier {
    var padding: CGFloat
    var cornerRadius: CGFloat
    var fillColor: Color

    public func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(fillColor)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(ApexTheme.subtleBorder, lineWidth: 0.5)
            )
    }
}

public extension View {
    func appleCard(
        padding: CGFloat = 18,
        cornerRadius: CGFloat = 22,
        fill: Color = ApexTheme.cardSurface
    ) -> some View {
        modifier(AppleCardModifier(padding: padding, cornerRadius: cornerRadius, fillColor: fill))
    }
}

// MARK: - Clean Apple Telemetry Card
public struct AppleBiometricTile: View {
    let title: String
    let value: String
    let unit: String
    let detail: String
    let tint: Color
    let systemIcon: String
    var action: (() -> Void)? = nil

    public var body: some View {
        Button {
            Haptics.tap()
            action?()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: systemIcon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(tint)
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Spacer(minLength: 4)
                    if action != nil {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                }

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    if !unit.isEmpty {
                        Text(unit)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }

                Text(detail)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(tint.opacity(0.95))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .appleCard(padding: 16, cornerRadius: 20)
        }
        .buttonStyle(.plain)
    }
}
