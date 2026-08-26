import SwiftUI

/// Zanshin palette — washi paper, sumi ink, shu lacquer, kin gold, matcha tea.
/// Dark mode inverts the ink roles so the ensō keeps its contrast.
enum Theme {
    static let washi  = dynamic(0xF6F1E5, dark: 0x201C17)   // canvas
    static let paper  = dynamic(0xEEE7D7, dark: 0x2A251F)   // raised surface
    static let line   = dynamic(0xDDD3BE, dark: 0x3B352C)   // hairlines
    static let ink    = dynamic(0x26221C, dark: 0xEAE2D0)   // primary text
    static let inkSoft = dynamic(0x8A8172, dark: 0x9A9080)  // secondary text

    /// Primary accent surface (buttons, pills, the ink ring).
    static let sumi = dynamic(0x26221C, dark: 0xEDE5D3)
    /// Text/icons that sit on top of `sumi`.
    static let onSumi = dynamic(0xF6F1E5, dark: 0x201C17)

    static let shu    = dynamic(0xB03A2E, dark: 0xCE5347)   // crimson lacquer
    static let onShu  = dynamic(0xFBF5EA, dark: 0xFBF0E4)
    static let kin    = dynamic(0xC29B3C, dark: 0xD3AF52)   // gold leaf
    static let matcha = dynamic(0x77835A, dark: 0x93A06F)   // tea green

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
