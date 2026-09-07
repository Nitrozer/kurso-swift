import SwiftUI
import CoreText

/// Trois familles, trois roles, aucun recouvrement.
///
/// Les polices sont enregistrees au demarrage plutot que declarees dans un
/// Info.plist : le projet genere son Info.plist, et `UIAppFonts` n'a pas de
/// reglage de compilation equivalent.
enum KFont {

    /// Titres, chiffres, boutons. Graisses 700 et 800 uniquement.
    static func display(_ size: CGFloat, weight: Weight = .extraBold) -> Font {
        .custom(weight == .bold ? "Baloo2-Bold" : "Baloo2-ExtraBold", size: size)
    }

    /// Libelles et corps.
    static func body(_ size: CGFloat, weight: Weight = .semiBold) -> Font {
        .custom(weight.nunitoName, size: size)
    }

    /// Metadonnees. Toujours en capitales, avec 0,12 em d'interlettrage —
    /// jamais pour du texte lu, seulement pour des reperes.
    static func mono(_ size: CGFloat, weight: Weight = .regular) -> Font {
        .custom(weight.monoName, size: size)
    }

    enum Weight {
        case regular, semiBold, bold, extraBold

        var nunitoName: String {
            switch self {
            case .regular:   "Nunito-Regular"
            case .semiBold:  "Nunito-SemiBold"
            case .bold:      "Nunito-Bold"
            case .extraBold: "Nunito-ExtraBold"
            }
        }
        var monoName: String {
            switch self {
            case .regular:            "IBMPlexMono-Regular"
            case .semiBold, .bold:    "IBMPlexMono-Medium"
            case .extraBold:          "IBMPlexMono-SemiBold"
            }
        }
    }

    /// A appeler une fois au demarrage.
    static func register() {
        guard let urls = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) else { return }
        CTFontManagerRegisterFontURLs(urls as CFArray, .process, true, nil)
    }
}

/// Metadonnee : capitales + interlettrage, imposes ici pour qu'on ne puisse pas
/// les oublier au cas par cas.
struct MetaText: View {
    let text: String
    var size: CGFloat = 10
    var color: Color = K.inkSoft

    init(_ text: String, size: CGFloat = 10, color: Color = K.inkSoft) {
        self.text = text
        self.size = size
        self.color = color
    }

    var body: some View {
        Text(text.uppercased())
            .font(KFont.mono(size))
            .tracking(size * 0.12)
            .foregroundStyle(color)
    }
}

/// Titre. Au-dela de la taille Dynamic Type « grande », Baloo 2 cede la place a
/// Nunito : la lisibilite l'emporte sur le style.
struct DisplayText: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let text: String
    var size: CGFloat = 22
    var color: Color = K.ink

    init(_ text: String, size: CGFloat = 22, color: Color = K.ink) {
        self.text = text
        self.size = size
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(typeSize > .large ? KFont.body(size, weight: .extraBold) : KFont.display(size))
            .foregroundStyle(color)
    }
}
