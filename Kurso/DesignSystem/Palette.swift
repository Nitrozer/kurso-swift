import SwiftUI
import KursoCore

extension Color {
    /// Construit une couleur depuis un jeton hexadecimal du module pur.
    init(token: String) {
        let hex = token.hasPrefix("#") ? String(token.dropFirst()) : token
        let value = UInt64(hex, radix: 16) ?? 0
        self.init(
            .sRGB,
            red:   Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8)  & 0xFF) / 255,
            blue:  Double( value        & 0xFF) / 255
        )
    }
}

/// La palette. Chaque teinte a un sens unique — on nomme l'usage, pas la couleur,
/// pour qu'un appel du genre `.blue` reste impossible.
enum K {
    static let brand       = Color(token: DesignTokens.Palette.brand)
    static let ink         = Color(token: DesignTokens.Palette.ink)
    static let reward      = Color(token: DesignTokens.Palette.reward)
    static let success     = Color(token: DesignTokens.Palette.success)
    static let alertBg     = Color(token: DesignTokens.Palette.alertBg)
    static let alertOnDark = Color(token: DesignTokens.Palette.alertOnDark)
    static let flame       = Color(token: DesignTokens.Palette.flame)
    static let eraser      = Color(token: DesignTokens.Palette.eraser)
    static let fadedInk    = Color(token: DesignTokens.Palette.fadedInk)
    static let endangered  = Color(token: DesignTokens.Palette.endangered)
    static let paper       = Color(token: DesignTokens.Palette.paper)
    static let paperAlt    = Color(token: DesignTokens.Palette.paperAlt)
    static let inkSoft     = Color(token: DesignTokens.Palette.inkSoft)
    static let inkBody     = Color(token: DesignTokens.Palette.inkBody)
    static let doneFill    = Color(token: DesignTokens.Palette.doneFill)
    static let pendingLine = Color(token: DesignTokens.Palette.pendingLine)
    static let hairline    = Color(token: DesignTokens.Palette.hairline)
}
