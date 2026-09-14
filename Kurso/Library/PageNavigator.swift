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
    /// Poser une image sur la page ouverte, pas en creer une nouvelle.
    var onAddImageHere: () -> Void = {}
    var onCollapse: () -> Void = {}

    enum Kind { case handwritten, pdf, image }

    var body: some View {
        VStack(spacing: 0) {
            addBar
            currentPageBar
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                        thumbnail(page, number: index + 1)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
            }
            .scrollIndicators(.hidden)
        }
        .frame(width: 168)
        .background(K.paper)
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

    /// Ce qu'on pose SUR la page ouverte, distinct de ce qui cree une page.
    /// En haut comme le reste : la palette PencilKit flotte en bas.
    private var currentPageBar: some View {
        Button { onAddImageHere() } label: {
            HStack(spacing: 8) {
                Glyph(kind: .plus, size: 12)
                Text("Image sur cette page")
                    .font(KFont.body(11.5, weight: .extraBold))
                    .foregroundStyle(K.ink)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(K.paper)
            .overlay(alignment: .bottom) {
                Rectangle().fill(K.ink.opacity(0.12)).frame(height: 1)
            }
        }
        .buttonStyle(.plain)
    }

    /// En HAUT du panneau : la palette PencilKit flotte en bas et recouvrait
    /// entierement ce bouton.
    private var addBar: some View {
        HStack(spacing: 0) {
            Button { onCollapse() } label: {
                ChevronGlyph()
                    .stroke(K.ink, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                    .frame(width: 9, height: 9)
                    .frame(width: 34, height: 40)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Replier les pages")
            menuBar
        }
        .background(K.paperAlt)
        .overlay(alignment: .bottom) {
            Rectangle().fill(K.ink.opacity(0.12)).frame(height: 1)
        }
    }

    private var menuBar: some View {
        Menu {
            Button("Page manuscrite") { onAdd(.handwritten, end) }
            Button("Pages d'un PDF") { onAdd(.pdf, end) }
            Button("Une image") { onAdd(.image, end) }
        } label: {
            HStack(spacing: 8) {
                Glyph(kind: .plus, size: 13)
                Text("Ajouter une page")
                    .font(KFont.body(12.5, weight: .extraBold))
                    .foregroundStyle(K.ink)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .menuStyle(.borderlessButton)
    }

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
