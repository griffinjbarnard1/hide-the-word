import ScriptureMemory
import SwiftUI
import UIKit

extension Color {
    static let screenBackground = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.08, green: 0.07, blue: 0.06, alpha: 1)
            : UIColor(red: 0.9686, green: 0.949, blue: 0.9137, alpha: 1)
    })

    static let paper = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.13, green: 0.12, blue: 0.11, alpha: 1)
            : UIColor(red: 0.9882, green: 0.9804, blue: 0.9647, alpha: 1)
    })

    static let accentMoss = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.48, green: 0.56, blue: 0.42, alpha: 1)
            : UIColor(red: 0.3686, green: 0.4196, blue: 0.3216, alpha: 1)
    })

    static let accentGold = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.84, green: 0.72, blue: 0.45, alpha: 1)
            : UIColor(red: 0.7412, green: 0.6157, blue: 0.3529, alpha: 1)
    })

    static let mutedText = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.58, green: 0.55, blue: 0.50, alpha: 1)
            : UIColor(red: 0.5412, green: 0.5098, blue: 0.4706, alpha: 1)
    })

    static let borderSand = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.22, green: 0.20, blue: 0.18, alpha: 1)
            : UIColor(red: 0.8706, green: 0.8392, blue: 0.7843, alpha: 1)
    })

    static let primaryText = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.92, green: 0.90, blue: 0.87, alpha: 1)
            : UIColor(red: 0.1216, green: 0.1059, blue: 0.0902, alpha: 1)
    })
}

struct CardSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(20)
            .background(Color.paper)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.borderSand, lineWidth: 1)
            )
            .shadow(color: Color.primaryText.opacity(0.04), radius: 14, y: 8)
    }
}

extension View {
    func cardSurface() -> some View {
        modifier(CardSurface())
    }
}

struct StatusPill: View {
    let title: String
    var tint: Color = .accentMoss

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(tint.opacity(0.1))
            .clipShape(Capsule())
    }
}

struct MasteryBadge: View {
    let tier: MasteryTier

    var body: some View {
        Label(tier.title, systemImage: tier.systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }

    private var color: Color {
        switch tier {
        case .learning: return .mutedText
        case .familiar: return .accentGold
        case .memorized: return .accentMoss
        case .mastered: return Color(red: 0.55, green: 0.42, blue: 0.68)
        }
    }
}

struct ScalableCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, 22)
            .frame(height: 56)
            .frame(maxWidth: .infinity)
            .background(Color.accentMoss.opacity(configuration.isPressed ? 0.88 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var fullWidth = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Color.primaryText)
            .padding(.horizontal, 22)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .frame(height: 56)
            .background(Color.paper.opacity(configuration.isPressed ? 0.92 : 1))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.borderSand, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct FilledSoftButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Color.primaryText)
            .padding(.horizontal, 22)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.accentMoss.opacity(configuration.isPressed ? 0.14 : 0.10))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
