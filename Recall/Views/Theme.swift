import SwiftUI
import UIKit

/// Warm "paper" palette in light, warm graphite in dark. Text never goes pure white.
enum Palette {
    static let bg        = dyn(0xF5F1EA, 0x151412)
    static let surface   = dyn(0xFFFFFF, 0x211F1C)
    static let surface2  = dyn(0xEBE5DA, 0x2C2A26)
    static let ink       = dyn(0x1C1A17, 0xECE7DF)
    static let ink2      = dyn(0x5F5950, 0xA8A196)
    static let line      = dyn(0x1C1A17, 0x4A463F)
    static let shadow    = dyn(0x1C1A17, 0x000000)
    static let accent    = dyn(0x226B5C, 0x62C4AC)
    static let onAccent  = dyn(0xFFFFFF, 0x0E1F1B)
    static let accentBg  = dyn(0xDCEDE7, 0x1D3530)
    static let good      = dyn(0x1E7A4C, 0x58C98F)
    static let goodBg    = dyn(0xDDF2E5, 0x16301F)
    static let bad       = dyn(0xB4361F, 0xF08A73)
    static let badBg     = dyn(0xF9E0DA, 0x3A1E18)
    static let flame     = dyn(0xD9622B, 0xF2925C)
    static let flameBg   = dyn(0xFBE6D9, 0x3A2416)
    static let violet    = dyn(0x5B4BC4, 0xA99CF5)
    static let violetBg  = dyn(0xE7E3FA, 0x27223F)

    private static func dyn(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

extension Font {
    static let display = Font.system(.largeTitle, design: .serif).weight(.bold)
    static let question = Font.system(.title2, design: .serif).weight(.medium)
    static let cardTitle = Font.system(.title3, design: .serif).weight(.semibold)
}

// MARK: Tactile surfaces

struct TactileCard: ViewModifier {
    var fill: Color = Palette.surface
    var stroke: Color = Palette.line
    var radius: CGFloat = 20
    var depth: CGFloat = 3
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(fill)
                    .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(stroke.opacity(0.9), lineWidth: 1.5))
                    .background(RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(Palette.shadow).offset(y: depth))
            )
            .padding(.bottom, depth)
    }
}

struct SoftCard: ViewModifier {
    var fill: Color = Palette.surface
    var radius: CGFloat = 20
    func body(content: Content) -> some View {
        content.background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill))
    }
}

extension View {
    func tactile(fill: Color = Palette.surface, stroke: Color = Palette.line, radius: CGFloat = 20, depth: CGFloat = 3) -> some View {
        modifier(TactileCard(fill: fill, stroke: stroke, radius: radius, depth: depth))
    }
    func soft(_ fill: Color = Palette.surface, radius: CGFloat = 20) -> some View {
        modifier(SoftCard(fill: fill, radius: radius))
    }
}

/// Pressable button that sinks into its hard shadow.
struct PressStyle: ButtonStyle {
    var fill: Color = Palette.surface
    var stroke: Color = Palette.line
    var radius: CGFloat = 18
    var depth: CGFloat = 3
    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(fill)
                    .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(stroke.opacity(0.9), lineWidth: 1.5))
            )
            .offset(y: pressed ? depth : 0)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Palette.shadow).offset(y: depth)
            )
            .padding(.bottom, depth)
            .animation(.spring(duration: 0.18), value: pressed)
    }
}

struct PrimaryButton: View {
    let title: String
    var icon: String? = nil
    var fill: Color = Palette.accent
    var fg: Color = Palette.onAccent
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon) }
                Text(title)
            }
            .font(.headline)
            .foregroundStyle(fg)
            .frame(maxWidth: .infinity, minHeight: 54)
        }
        .buttonStyle(PressStyle(fill: fill, radius: 16))
        .accessibilityIdentifier(title)
    }
}

struct ProgressBar: View {
    var value: Double
    var tint: Color = Palette.accent
    var height: CGFloat = 8
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.surface2)
                Capsule().fill(tint)
                    .frame(width: max(value > 0 ? height : 0, geo.size.width * min(1, max(0, value))))
            }
        }
        .frame(height: height)
        .animation(.spring(duration: 0.4), value: value)
        .accessibilityElement()
        .accessibilityValue("\(Int(value * 100)) процентов")
    }
}

struct Chip: View {
    let text: String
    var icon: String? = nil
    var fg: Color = Palette.ink2
    var bg: Color = Palette.surface2
    var body: some View {
        HStack(spacing: 4) {
            if let icon { Image(systemName: icon).imageScale(.small) }
            Text(text)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(fg)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(bg))
    }
}

enum Haptics {
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func error() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
}

func plural(_ n: Int, _ one: String, _ few: String, _ many: String) -> String {
    let n10 = n % 10, n100 = n % 100
    if n10 == 1 && n100 != 11 { return one }
    if (2...4).contains(n10) && !(12...14).contains(n100) { return few }
    return many
}
