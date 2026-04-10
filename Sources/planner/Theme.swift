#if canImport(AppKit) && canImport(SwiftUI)
import AppKit
import SwiftUI

struct AppTheme: Identifiable, Hashable {
    let id: String
    let name: String
    let base: Color
    let mantle: Color
    let crust: Color
    let text: Color
    let subtext1: Color
    let subtext0: Color
    let surface0: Color
    let surface1: Color
    let surface2: Color
    let overlay0: Color
    let overlay1: Color
    let overlay2: Color
    let blue: Color
    let lavender: Color
    let green: Color
    let yellow: Color
    let peach: Color
    let red: Color
    let mauve: Color
    let pink: Color
    let teal: Color
    let isSystem: Bool
    let isDark: Bool

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: AppTheme, rhs: AppTheme) -> Bool { lhs.id == rhs.id }
}

extension AppTheme {
    static let allThemes: [AppTheme] = [system, latte, frappe, macchiato, mocha]

    static let system = AppTheme(
        id: "system", name: "Default",
        base: Color(nsColor: .textBackgroundColor),
        mantle: Color(nsColor: .windowBackgroundColor),
        crust: Color(nsColor: .controlBackgroundColor),
        text: Color(nsColor: .labelColor),
        subtext1: Color(nsColor: .secondaryLabelColor),
        subtext0: Color(nsColor: .tertiaryLabelColor),
        surface0: Color(nsColor: .separatorColor),
        surface1: Color(nsColor: .quaternaryLabelColor),
        surface2: Color(nsColor: .placeholderTextColor),
        overlay0: Color.secondary.opacity(0.3),
        overlay1: Color.secondary.opacity(0.5),
        overlay2: Color.secondary.opacity(0.7),
        blue: .accentColor,
        lavender: Color(hex: 0x7287FD),
        green: Color(hex: 0x40A02B),
        yellow: Color(hex: 0xDF8E1D),
        peach: Color(hex: 0xFE640B),
        red: Color(hex: 0xD20F39),
        mauve: Color(hex: 0x8839EF),
        pink: Color(hex: 0xEA76CB),
        teal: Color(hex: 0x179299),
        isSystem: true,
        isDark: false
    )

    static let latte = AppTheme(
        id: "latte", name: "Catppuccin Latte",
        base: Color(hex: 0xEFF1F5),
        mantle: Color(hex: 0xE6E9EF),
        crust: Color(hex: 0xDCE0E8),
        text: Color(hex: 0x4C4F69),
        subtext1: Color(hex: 0x5C5F77),
        subtext0: Color(hex: 0x6C6F85),
        surface0: Color(hex: 0xCCD0DA),
        surface1: Color(hex: 0xBCC0CC),
        surface2: Color(hex: 0xACB0BE),
        overlay0: Color(hex: 0x9CA0B0),
        overlay1: Color(hex: 0x8C8FA1),
        overlay2: Color(hex: 0x7C7F93),
        blue: Color(hex: 0x1E66F5),
        lavender: Color(hex: 0x7287FD),
        green: Color(hex: 0x40A02B),
        yellow: Color(hex: 0xDF8E1D),
        peach: Color(hex: 0xFE640B),
        red: Color(hex: 0xD20F39),
        mauve: Color(hex: 0x8839EF),
        pink: Color(hex: 0xEA76CB),
        teal: Color(hex: 0x179299),
        isSystem: false,
        isDark: false
    )

    static let frappe = AppTheme(
        id: "frappe", name: "Catppuccin Frappé",
        base: Color(hex: 0x303446),
        mantle: Color(hex: 0x292C3C),
        crust: Color(hex: 0x232634),
        text: Color(hex: 0xC6D0F5),
        subtext1: Color(hex: 0xB5BFE2),
        subtext0: Color(hex: 0xA5ADCE),
        surface0: Color(hex: 0x414559),
        surface1: Color(hex: 0x51576D),
        surface2: Color(hex: 0x626880),
        overlay0: Color(hex: 0x737994),
        overlay1: Color(hex: 0x838BA7),
        overlay2: Color(hex: 0x949CBB),
        blue: Color(hex: 0x8CAAEE),
        lavender: Color(hex: 0xBABBF1),
        green: Color(hex: 0xA6D189),
        yellow: Color(hex: 0xE5C890),
        peach: Color(hex: 0xEF9F76),
        red: Color(hex: 0xE78284),
        mauve: Color(hex: 0xCA9EE6),
        pink: Color(hex: 0xF4B8E4),
        teal: Color(hex: 0x81C8BE),
        isSystem: false,
        isDark: true
    )

    static let macchiato = AppTheme(
        id: "macchiato", name: "Catppuccin Macchiato",
        base: Color(hex: 0x24273A),
        mantle: Color(hex: 0x1E2030),
        crust: Color(hex: 0x181926),
        text: Color(hex: 0xCAD3F5),
        subtext1: Color(hex: 0xB8C0E0),
        subtext0: Color(hex: 0xA5ADCB),
        surface0: Color(hex: 0x363A4F),
        surface1: Color(hex: 0x494D64),
        surface2: Color(hex: 0x5B6078),
        overlay0: Color(hex: 0x6E738D),
        overlay1: Color(hex: 0x8087A2),
        overlay2: Color(hex: 0x939AB7),
        blue: Color(hex: 0x8AADF4),
        lavender: Color(hex: 0xB7BDF8),
        green: Color(hex: 0xA6DA95),
        yellow: Color(hex: 0xEED49F),
        peach: Color(hex: 0xF5A97F),
        red: Color(hex: 0xED8796),
        mauve: Color(hex: 0xC6A0F6),
        pink: Color(hex: 0xF5BDE6),
        teal: Color(hex: 0x8BD5CA),
        isSystem: false,
        isDark: true
    )

    static let mocha = AppTheme(
        id: "mocha", name: "Catppuccin Mocha",
        base: Color(hex: 0x1E1E2E),
        mantle: Color(hex: 0x181825),
        crust: Color(hex: 0x11111B),
        text: Color(hex: 0xCDD6F4),
        subtext1: Color(hex: 0xBAC2DE),
        subtext0: Color(hex: 0xA6ADC8),
        surface0: Color(hex: 0x313244),
        surface1: Color(hex: 0x45475A),
        surface2: Color(hex: 0x585B70),
        overlay0: Color(hex: 0x6C7086),
        overlay1: Color(hex: 0x7F849C),
        overlay2: Color(hex: 0x9399B2),
        blue: Color(hex: 0x89B4FA),
        lavender: Color(hex: 0xB4BEFE),
        green: Color(hex: 0xA6E3A1),
        yellow: Color(hex: 0xF9E2AF),
        peach: Color(hex: 0xFAB387),
        red: Color(hex: 0xF38BA8),
        mauve: Color(hex: 0xCBA6F7),
        pink: Color(hex: 0xF5C2E7),
        teal: Color(hex: 0x94E2D5),
        isSystem: false,
        isDark: true
    )
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

private struct ThemeKey: EnvironmentKey {
    static let defaultValue: AppTheme = .system
}

extension EnvironmentValues {
    var theme: AppTheme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}
#endif
