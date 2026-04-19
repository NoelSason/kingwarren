import SwiftUI

extension Color {
    static let bg        = Color(hex: 0xFAFAF7)
    static let surface   = Color(hex: 0xFFFFFF)
    static let ink       = Color(hex: 0x0D0D0C)
    static let ink2      = Color(hex: 0x4B4B47)
    static let ink3      = Color(hex: 0x8A8A82)
    static let hair      = Color(hex: 0x0D0D0C, alpha: 0.08)
    static let ocean     = Color(hex: 0x0B4F6C)
    static let oceanInk  = Color(hex: 0x093B52)
    static let kelp      = Color(hex: 0x3F7D58)
    static let coral     = Color(hex: 0xE85D3D)
    static let sand      = Color(hex: 0xF1EBDE)
    static let warn      = Color(hex: 0xC7591A)
    static let bad       = Color(hex: 0xC7441F)

    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

enum Score {
    static func color(_ score: Int) -> Color {
        switch score {
        case 80...:    return Color(hex: 0x3F7D58)
        case 60..<80:  return Color(hex: 0x6B8A3A)
        case 40..<60:  return Color(hex: 0xB58A20)
        case 20..<40:  return Color(hex: 0xC7591A)
        default:       return Color(hex: 0xC7441F)
        }
    }

    static func label(_ score: Int) -> String {
        switch score {
        case 85...:    return "Excellent"
        case 65..<85:  return "Good"
        case 45..<65:  return "Fair"
        case 25..<45:  return "Poor"
        default:       return "Very Poor"
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
