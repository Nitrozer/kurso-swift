import SwiftUI
import KursoCore

/// Les quatre etats de l'autocollant.
enum StickerState {
    /// Ombre pleine, 5 px.
    case rest
    /// L'ombre se comprime, le bloc descend de 3 px.
    case pressed
    /// Plus d'ombre du tout — il ne se touche plus.
    case done
    /// Pointilles, aucun fond.
    case upcoming
}

/// L'autocollant : le composant de base, tout en decoule.
///
/// Un element est un objet POSE sur la page, pas une surface qui flotte.
/// L'ombre est dure et decalee : une ombre floutee transformerait le meme bloc
/// en carte de tableau de bord, ce que la direction artistique proscrit.
struct Sticker: ViewModifier {
    var fill: Color = K.paperAlt
    var radius: CGFloat = 18
    var state: StickerState = .rest

    func body(content: Content) -> some View {
        content
            .background(backgroundFill, in: shape)
            .overlay(border)
            .offset(y: state == .pressed ? DesignTokens.Sticker.pressOffset : 0)
            .background(alignment: .top) { hardShadow }
            .animation(.spring(duration: DesignTokens.Motion.pressSeconds), value: state == .pressed)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }

    private var backgroundFill: Color {
        switch state {
        case .rest, .pressed: fill
        case .done:           K.doneFill
        case .upcoming:       .clear
        }
    }

    @ViewBuilder private var border: some View {
        switch state {
        case .upcoming:
            shape.strokeBorder(
                K.pendingLine,
                style: StrokeStyle(lineWidth: DesignTokens.Sticker.borderWidth, dash: [7, 6])
            )
        default:
            shape.strokeBorder(K.ink, lineWidth: DesignTokens.Sticker.borderWidth)
        }
    }

    /// L'ombre est un second bloc decale, pas un `shadow` : `shadow` floute
    /// toujours un peu, et le flou est precisement ce qu'on refuse.
    @ViewBuilder private var hardShadow: some View {
        switch state {
        case .rest:
            shape.fill(K.ink).offset(y: DesignTokens.Sticker.shadowRest)
        case .pressed:
            shape.fill(K.ink).offset(y: DesignTokens.Sticker.shadowPressed + DesignTokens.Sticker.pressOffset)
        case .done, .upcoming:
            EmptyView()
        }
    }
}

extension View {
    func sticker(fill: Color = K.paperAlt, radius: CGFloat = 18, state: StickerState = .rest) -> some View {
        modifier(Sticker(fill: fill, radius: radius, state: state))
    }
}

/// Bouton autocollant. Un seul bouton jaune par ecran ; le contour nu est
/// l'action secondaire, jamais un bouton gris.
struct StickerButtonStyle: ButtonStyle {
    enum Kind { case primary, brand, confirm, secondary }
    var kind: Kind = .primary
    var radius: CGFloat = 16

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(KFont.display(17))
            .foregroundStyle(foreground)
            .padding(.vertical, 13)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .sticker(fill: fill, radius: radius, state: configuration.isPressed ? .pressed : .rest)
    }

    private var fill: Color {
        switch kind {
        case .primary:   K.reward
        case .brand:     K.brand
        case .confirm:   K.success
        case .secondary: .clear
        }
    }

    /// Le jaune ne porte jamais de texte clair : toujours l'encre graphite.
    private var foreground: Color {
        switch kind {
        case .primary, .secondary: K.ink
        case .brand, .confirm:     K.paperAlt
        }
    }
}
