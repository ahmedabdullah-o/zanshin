import SwiftUI

/// Washi and Sumi use the same canvas, surface, ink, and accent colors as Komorebi.
enum Theme {
    static let washi = dynamic(0xF5F0E6, dark: 0x242624)
    static let paper = dynamic(0xFFFCF6, dark: 0x30322E)
    static let line = dynamic(0xDDD7C9, dark: 0x505149)
    static let ink = dynamic(0x302F29, dark: 0xEEE7DA)
    static let inkSoft = dynamic(0x706E63, dark: 0xB9B2A4)
    static let accent = dynamic(0x58664B, dark: 0xD2AF73)
    static let onAccent = dynamic(0xFFFCF6, dark: 0x242624)

    static let sumi = ink
    static let shu = dynamic(0x9E3E35, dark: 0xF09588)
    static let onShu = dynamic(0xFFFAFA, dark: 0x242624)
    static let kin = dynamic(0x886524, dark: 0xD2AF73)
    static let matcha = dynamic(0x58664B, dark: 0xA6BA8D)
    static let onMatcha = dynamic(0xFFFCF6, dark: 0x242624)

    static let cardRadius: CGFloat = 15
    static let controlRadius: CGFloat = 9

    static func appearance(prefersDark: Bool?) -> NSAppearance? {
        prefersDark.flatMap { NSAppearance(named: $0 ? .darkAqua : .aqua) }
    }

    static func dynamic(_ light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let hex = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}

/// The ink that draws the ensō as practice deepens.
enum BladeTheme: String, CaseIterable, Identifiable {
    case sumi
    case shu
    case matcha
    case kin

    var id: String { rawValue }

    var name: String {
        switch self {
        case .sumi: return "Sumi"
        case .shu: return "Shu"
        case .matcha: return "Matcha"
        case .kin: return "Kin"
        }
    }

    var swatch: Color {
        switch self {
        case .sumi: return Theme.sumi
        case .shu: return Theme.shu
        case .matcha: return Theme.matcha
        case .kin: return Theme.kin
        }
    }

    /// The color of the ensō stroke while a focus session runs.
    var ringColor: Color {
        swatch
    }
}

/// Public-domain woodblock prints also used by Komorebi's Washi and Sumi themes.
struct ThemeArtwork: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Theme.washi
                Image(colorScheme == .dark ? "SumiArtwork" : "WashiArtwork")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .scaleEffect(1.16)
                Theme.washi.opacity(contrast == .increased ? 0.88 : 0.60)
            }
            .clipped()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

extension View {
    func paperCard(opacity: Double = 0.96) -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.cardRadius)
        return padding(14)
            .frame(maxWidth: .infinity)
            .background(Theme.paper.opacity(opacity), in: shape)
            .overlay { shape.strokeBorder(Theme.line).allowsHitTesting(false) }
    }
}
