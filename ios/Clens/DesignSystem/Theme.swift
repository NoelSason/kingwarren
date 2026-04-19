import SwiftUI

extension Color {
    // Adaptive colors — automatically switch with light/dark mode
    static let bg      = Color(uiColor: .init(light: 0xFAFAF7, dark: 0x0D0D0C))
    static let surface = Color(uiColor: .init(light: 0xFFFFFF, dark: 0x1C1C1A))
    static let ink     = Color(uiColor: .init(light: 0x0D0D0C, dark: 0xF0F0EC))
    static let ink2    = Color(uiColor: .init(light: 0x4B4B47, dark: 0xAAAAAA))
    static let ink3    = Color(uiColor: .init(light: 0x8A8A82, dark: 0x666660))
    static let hair    = Color(uiColor: .init(light: UIColor(white: 0, alpha: 0.08),
                                              dark:  UIColor(white: 1, alpha: 0.10)))
    static let sand    = Color(uiColor: .init(light: 0xF1EBDE, dark: 0x252520))
    static let fill1   = Color(uiColor: .init(light: 0xF0EFE9, dark: 0x2A2A26))

    // Non-adaptive — same in both modes
    static let ocean    = Color(hex: 0x0B4F6C)
    static let oceanInk = Color(hex: 0x093B52)
    static let kelp     = Color(hex: 0x3F7D58)
    static let coral    = Color(hex: 0xE85D3D)
    static let warn     = Color(hex: 0xC7591A)
    static let bad      = Color(hex: 0xC7441F)

    // Ocean-card surfaces (Live Ocean Modifier, chart cards) — adaptive.
    static let oceanCardBg     = Color(uiColor: .init(light: 0xEAF4F7, dark: 0x0F2A35))
    static let oceanCardStroke = Color(uiColor: .init(light: 0xBFD9E0, dark: 0x1E4556))
    static let oceanCardText   = Color(uiColor: .init(light: 0x093B52, dark: 0xCFE7F1))

    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8)  & 0xFF) / 255.0
        let b = Double(hex & 0xFF)          / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

private extension UIColor {
    convenience init(light: UInt32, dark: UInt32) {
        self.init { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(hex: dark)
                : UIColor(hex: light)
        }
    }

    convenience init(light: UIColor, dark: UIColor) {
        self.init { tc in tc.userInterfaceStyle == .dark ? dark : light }
    }

    convenience init(hex: UInt32) {
        let r = CGFloat((hex >> 16) & 0xFF) / 255
        let g = CGFloat((hex >> 8)  & 0xFF) / 255
        let b = CGFloat(hex & 0xFF)          / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}

enum Score {
    static func color(_ score: Int) -> Color {
        switch score {
        case 80...:   return Color(hex: 0x3F7D58)
        case 60..<80: return Color(hex: 0x6B8A3A)
        case 40..<60: return Color(hex: 0xB58A20)
        case 20..<40: return Color(hex: 0xC7591A)
        default:      return Color(hex: 0xC7441F)
        }
    }

    static func label(_ score: Int) -> String {
        switch score {
        case 85...:   return "Excellent"
        case 65..<85: return "Good"
        case 45..<65: return "Fair"
        case 25..<45: return "Poor"
        default:      return "Very Poor"
        }
    }
}

extension Font {
    static func serif(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}
