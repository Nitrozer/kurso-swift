#if os(iOS)
import SwiftUI
import KursoCore
import KursoModels

/// Le panneau des pages, a gauche du cahier ouvert.
///
/// On entre dans un cahier et on tombe sur la feuille, pas sur une liste :
/// c'est un cahier, pas un dossier. Le panneau sert a se deplacer dedans et a
/// en ajouter — page manuscrite, diapos d'un PDF, ou image.
struct PageNavigator: View {
    let pages: [Page]
    let current: Page?
    var onSelect: (Page) -> Void
    var onAdd: (Kind, Double) -> Void
    var onDuplicate: (Page) -> Void
    var onDelete: (Page) -> Void
    var onCollapse: () -> Void = {}

    enum Kind { case handwritten, pdf, image }

    var body: some View {
        VStack(spacing: 0) {
            collapseBar
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                        thumbnail(page, number: index + 1)
                    }
                    // L'emplacement suivant, en pointilles : on voit ou la
                    // prochaine page ira avant meme de l'avoir creee.
                    nextSlot
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
            }
            .scrollIndicators(.hidden)
        }
        .frame(width: 168)
        .background(K.paper)
    }

    /// Le seul bouton de la barre : refermer le panneau.
    private var collapseBar: some View {
        HStack {
            Button { onCollapse() } label: {
                ChevronGlyph()
                    .stroke(K.ink, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                    .frame(width: 9, height: 9)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Replier les pages")
            Spacer(minLength: 0)
            Text("\(pages.count) page\(pages.count > 1 ? "s" : "")")
                .font(KFont.mono(9.5))
                .foregroundStyle(K.inkSoft)
                .padding(.trailing, 14)
        }
        .background(K.paperAlt)
        .overlay(alignment: .bottom) {
            Rectangle().fill(K.ink.opacity(0.12)).frame(height: 1)
        }
    }

    /// L'emplacement de la page suivante : grise, avec un plus dedans.
    private var nextSlot: some View {
        Menu {
            Button("Page manuscrite") { onAdd(.handwritten, end) }
            Button("Pages d'un PDF") { onAdd(.pdf, end) }
            Button("Une image") { onAdd(.image, end) }
        } label: {
            VStack(spacing: 5) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(K.ink.opacity(0.03))
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(K.ink.opacity(0.3),
                                      style: StrokeStyle(lineWidth: 2, dash: [7, 5]))
                    VStack(spacing: 6) {
                        Glyph(kind: .plus, size: 18, color: K.ink.opacity(0.45))
                        Text("Ajouter")
                            .font(KFont.body(10.5, weight: .extraBold))
                            .foregroundStyle(K.ink.opacity(0.45))
                    }
                }
                .frame(width: 108, height: 148)
                Text("\(pages.count + 1)")
                    .font(KFont.mono(9.5))
                    .foregroundStyle(K.inkSoft.opacity(0.6))
            }
        }
        .menuStyle(.borderlessButton)
    }

    // MARK: Une vignette

    private func thumbnail(_ page: Page, number: Int) -> some View {
        let isCurrent = page.id == current?.id
        return Button { onSelect(page) } label: {
            VStack(spacing: 5) {
                PagePreview(page: page)
                    .frame(width: 108, height: 148)
                    .background(K.paperAlt)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(isCurrent ? K.brand : K.ink.opacity(0.22),
                                      lineWidth: isCurrent ? 3 : 1.5))
                HStack(spacing: 5) {
                    Text("\(number)")
                        .font(KFont.mono(9.5))
                        .foregroundStyle(isCurrent ? K.brand : K.inkSoft)
                    if page.pdfAssetID != nil || page.photo != nil {
                        Text(page.pdfAssetID != nil ? "PDF" : "IMG")
                            .font(KFont.mono(8))
                            .foregroundStyle(K.inkSoft)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Ajouter une page avant") { onAdd(.handwritten, before(page)) }
            Button("Ajouter une page après") { onAdd(.handwritten, after(page)) }
            Button("Dupliquer") { onDuplicate(page) }
            Divider()
            Button("Supprimer", role: .destructive) { onDelete(page) }
        }
    }

    // MARK: Ajouter

    // MARK: Rangs

    private var end: Double { PageOrdering.append(to: pages.map(\.position)) }

    private func before(_ page: Page) -> Double {
        let previous = pages.last { $0.position < page.position }?.position
        return PageOrdering.position(after: previous, before: page.position)
    }

    private func after(_ page: Page) -> Double {
        let next = pages.first { $0.position > page.position }?.position
        return PageOrdering.position(after: page.position, before: next)
    }
}
#endif
