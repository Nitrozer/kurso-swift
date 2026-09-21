#if os(iOS)
import SwiftUI
import KursoCore
import KursoModels

/// Les signets d'une page, au bord droit.
///
/// Ce sont les onglets de papier qu'on colle dans un classeur : on les voit en
/// tournant les pages et on retrouve l'endroit sans avoir rien a lire. Ils ne
/// prennent aucun toucher — une paume posee sur le bord ne doit pas effacer une
/// marque. On pose et on retire par le bouton, jamais par l'onglet.
struct BookmarkRail: View {
    struct Tab: Identifiable {
        let id: UUID
        let height: Double
    }

    let tabs: [Tab]
    let viewport: PaperBackdrop.Viewport
    /// Vrai quand un signet est deja au milieu de l'ecran : le bouton se
    /// remplit, et le second appui le retire.
    let isMarked: Bool
    var onToggle: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ZStack(alignment: .topTrailing) {
                ForEach(visible) { tab in
                    onglet.offset(y: onScreen(tab.height) - 13)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .allowsHitTesting(false)

            button
                .padding(.top, 14)
                .padding(.trailing, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    }

    /// Seuls ceux qui tombent dans la fenetre : une page en compte parfois dix,
    /// et les autres n'ont rien a dessiner.
    private var visible: [Tab] {
        tabs.filter { tab in
            let y = onScreen(tab.height)
            return y > -20 && y < viewport.size.height + 20
        }
    }

    private var onglet: some View {
        UnevenRoundedRectangle(topLeadingRadius: 5, bottomLeadingRadius: 5,
                               bottomTrailingRadius: 0, topTrailingRadius: 0,
                               style: .continuous)
            .fill(K.reward)
            .overlay(
                UnevenRoundedRectangle(topLeadingRadius: 5, bottomLeadingRadius: 5,
                                       bottomTrailingRadius: 0, topTrailingRadius: 0,
                                       style: .continuous)
                    .strokeBorder(K.ink, lineWidth: 2)
            )
            .frame(width: 16, height: 26)
    }

    private var button: some View {
        Button { onToggle() } label: {
            BookmarkGlyph()
                .fill(isMarked ? K.reward : K.paperAlt)
                .overlay(
                    BookmarkGlyph()
                        .stroke(K.ink, style: StrokeStyle(lineWidth: 2.6, lineJoin: .round))
                )
                .frame(width: 15, height: 19)
                .frame(width: 40, height: 40)
                .background(K.paperAlt, in: Circle())
                .overlay(Circle().strokeBorder(K.ink, lineWidth: 2.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isMarked ? "Retirer le signet" : "Poser un signet")
    }

    /// La hauteur d'un signet, en points d'ecran. Meme calcul que le calque
    /// d'ecoute : le repere suit la page quand on zoome ou qu'on fait defiler.
    private func onScreen(_ height: Double) -> CGFloat {
        CGFloat(height) * PaperBackdrop.pageHeight * viewport.zoom - viewport.offset.y
    }
}
#endif
