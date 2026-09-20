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
    /// Poser ou retirer l'intercalaire d'une page.
    var onTag: (Page, PageTag?) -> Void = { _, _ in }
    /// Le meme geste, sur plusieurs pages d'un coup.
    var onTagMany: (Set<UUID>, PageTag?) -> Void = { _, _ in }
    var onMoveMany: (Set<UUID>, PageOrdering.Destination) -> Void = { _, _ in }
    var onDeleteMany: (Set<UUID>) -> Void = { _ in }

    /// L'intercalaire regarde. `nil` : tout le cahier.
    @State private var divider: PageTag?
    /// Les pages cochees. Vide hors du mode selection.
    @State private var selection: Set<UUID> = []
    @State private var isSelecting = false

    enum Kind { case handwritten, pdf, image }

    var body: some View {
        VStack(spacing: 0) {
            if isSelecting { selectionBar } else { collapseBar }
            dividers
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(shown, id: \.page.id) { entry in
                        thumbnail(entry.page, number: entry.number)
                    }
                    // L'emplacement suivant, en pointilles : on voit ou la
                    // prochaine page ira avant meme de l'avoir creee.
                    nextSlot
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
            }
            .scrollIndicators(.hidden)
            if isSelecting { actions }
        }
        .frame(width: 168)
        .background(K.paper)
        #if DEBUG
        .task {
            // Ouvre le mode selection pour pouvoir le regarder : aucun tap
            // n'est simulable.
            if ProcessInfo.processInfo.arguments.contains("-selectPages"), !pages.isEmpty {
                isSelecting = true
                selection = Set(pages.prefix(2).map(\.id))
            }
        }
        #endif
        // Un intercalaire vide ne reste pas selectionne : on se retrouverait
        // devant un cahier vide sans comprendre pourquoi.
        .onChange(of: tokens) { _, now in
            divider = PageTag.stillThere(divider, in: now)
        }
    }

    /// L'en-tete pendant la selection.
    private var selectionBar: some View {
        HStack(spacing: 8) {
            Button(selection.count == shown.count ? "Aucune" : "Tout") {
                selection = selection.count == shown.count ? [] : Set(shown.map(\.page.id))
            }
            .buttonStyle(.plain)
            .font(KFont.body(10.5, weight: .extraBold))
            .foregroundStyle(K.brand)
            Text("\(selection.count)")
                .font(KFont.body(11.5, weight: .extraBold))
                .foregroundStyle(K.ink)
            Spacer(minLength: 0)
            Button("Terminé") { isSelecting = false; selection = [] }
                .buttonStyle(.plain)
                .font(KFont.body(10.5, weight: .extraBold))
                .foregroundStyle(K.ink)
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(K.reward.opacity(0.35))
        .overlay(alignment: .bottom) {
            Rectangle().fill(K.ink.opacity(0.12)).frame(height: 1)
        }
    }

    /// Ce qu'on peut faire a plusieurs pages a la fois.
    ///
    /// En pile, pas en rangee : dans un panneau de cent soixante-huit points,
    /// trois boutons cote a cote seraient trois cibles trop etroites.
    private var actions: some View {
        VStack(spacing: 7) {
            Menu {
                ForEach(PageTag.allCases, id: \.self) { tag in
                    Button(tag.label) { applyMany { onTagMany($0, tag) } }
                }
                Divider()
                Button("Retirer") { applyMany { onTagMany($0, nil) } }
            } label: {
                actionLabel("Intercalaire")
            }
            Menu {
                Button("Mettre au début") { applyMany { onMoveMany($0, .start) } }
                Button("Mettre à la fin") { applyMany { onMoveMany($0, .end) } }
            } label: {
                actionLabel("Déplacer")
            }
            Button {
                applyMany { onDeleteMany($0) }
            } label: {
                actionLabel("Supprimer", destructive: true)
            }
            .buttonStyle(.plain)
        }
        .disabled(selection.isEmpty)
        .opacity(selection.isEmpty ? 0.4 : 1)
        .padding(.horizontal, 12)
        .padding(.top, 12)
        // La pastille qui replie le rail flotte en bas a gauche de l'ecran,
        // pile sur cette pile : sans cette marge, « Supprimer » passait
        // dessous.
        .padding(.bottom, 56)
        .background(K.paperAlt)
        .overlay(alignment: .top) {
            Rectangle().fill(K.ink.opacity(0.12)).frame(height: 1)
        }
    }

    private func actionLabel(_ text: String, destructive: Bool = false) -> some View {
        Text(text)
            .font(KFont.body(11.5, weight: .extraBold))
            .foregroundStyle(destructive ? K.alertBg : K.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(destructive ? K.alertBg.opacity(0.08) : K.paper,
                        in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(destructive ? K.alertBg.opacity(0.35) : K.ink.opacity(0.16),
                              lineWidth: 1.5))
    }

    /// Agit puis sort du mode : on ne reste pas devant une selection dont on
    /// ne sait plus ce qu'elle porte.
    private func applyMany(_ work: (Set<UUID>) -> Void) {
        guard !selection.isEmpty else { return }
        work(selection)
        selection = []
        isSelecting = false
    }

    private func tickBorder(isCurrent: Bool, isTicked: Bool) -> Color {
        if isTicked { return K.success }
        return isCurrent ? K.brand : K.ink.opacity(0.22)
    }

    private func tick(_ on: Bool) -> some View {
        Circle()
            .fill(on ? K.success : K.paperAlt)
            .frame(width: 22, height: 22)
            .overlay(Circle().strokeBorder(on ? K.success : K.ink.opacity(0.3), lineWidth: 2))
            .overlay {
                if on {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(K.paperAlt)
                }
            }
            .padding(6)
    }

    private var tokens: [String] { pages.map(\.tagToken) }

    /// Les pages montrees, avec leur numero d'origine.
    ///
    /// Le numero est celui de la page DANS LE CAHIER, pas dans le filtre :
    /// une page reste la septieme meme quand on ne regarde que les exercices.
    private var shown: [(page: Page, number: Int)] {
        let numbered = pages.enumerated().map { (page: $0.element, number: $0.offset + 1) }
        return PageTag.keep(numbered, matching: divider) { $0.page.tagToken }
    }

    /// Les intercalaires du cahier, en onglets.
    @ViewBuilder
    private var dividers: some View {
        let available = PageTag.dividers(for: tokens)
        if !available.isEmpty {
            WrapLayout(spacing: 6, lineSpacing: 6) {
                tab(nil, label: "Tout", count: pages.count)
                ForEach(available, id: \.self) { tag in
                    tab(tag, label: tag.label, count: PageTag.count(tag, in: tokens))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(K.paper)
            .overlay(alignment: .bottom) {
                Rectangle().fill(K.ink.opacity(0.12)).frame(height: 1)
            }
        }
    }

    private func tab(_ tag: PageTag?, label: String, count: Int) -> some View {
        let isOn = divider == tag
        return Button { divider = tag } label: {
            HStack(spacing: 5) {
                if let tag {
                    Circle()
                        .fill(Color(token: tag.colorToken))
                        .frame(width: 7, height: 7)
                }
                Text(label)
                    .font(KFont.body(10.5, weight: .extraBold))
                    .foregroundStyle(isOn ? K.paperAlt : K.ink)
                Text("\(count)")
                    .font(KFont.mono(9))
                    .foregroundStyle(isOn ? K.paperAlt.opacity(0.7) : K.inkSoft)
            }
            .padding(.vertical, 6).padding(.horizontal, 10)
            .background(isOn ? K.ink : .clear, in: Capsule())
            .overlay(Capsule().strokeBorder(isOn ? .clear : K.ink.opacity(0.2), lineWidth: 1.5))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    /// Refermer le panneau.
    ///
    /// Toute la barre est le bouton, pas le seul chevron : un trait de neuf
    /// points dans une bande claire ne se voit pas, et on cherchait ou
    /// appuyer. Quarante-quatre points de haut, c'est la cible qu'un doigt
    /// trouve du premier coup.
    private var collapseBar: some View {
        Button { onCollapse() } label: {
            HStack(spacing: 8) {
                ChevronGlyph()
                    .stroke(K.ink, style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                    .frame(width: 10, height: 10)
                    .padding(.leading, 14)
                Text("\(pages.count) page\(pages.count > 1 ? "s" : "")")
                    .font(KFont.body(11.5, weight: .extraBold))
                    .foregroundStyle(K.ink)
                Spacer(minLength: 0)
                Text("REPLIER")
                    .font(KFont.body(9, weight: .extraBold))
                    .tracking(0.8)
                    .foregroundStyle(K.inkSoft)
                    .padding(.trailing, 14)
            }
            .frame(height: 44)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Replier les pages")
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
        let isTicked = selection.contains(page.id)
        return Button {
            if isSelecting {
                if isTicked { selection.remove(page.id) } else { selection.insert(page.id) }
            } else {
                onSelect(page)
            }
        } label: {
            VStack(spacing: 5) {
                PagePreview(page: page, renderWidth: 220)
                    .frame(width: 108, height: 148)
                    .background(K.paperAlt)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(tickBorder(isCurrent: isCurrent, isTicked: isTicked),
                                      lineWidth: isTicked || isCurrent ? 3 : 1.5))
                    .overlay(alignment: .topTrailing) {
                        if isSelecting { tick(isTicked) }
                    }
                HStack(spacing: 5) {
                    if let tag = PageTag.named(page.tagToken) {
                        Circle()
                            .fill(Color(token: tag.colorToken))
                            .frame(width: 7, height: 7)
                    }
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
            if !isSelecting {
                Button("Sélectionner des pages") {
                    isSelecting = true
                    selection = [page.id]
                }
                // Un PDF importe fait trente pages : les cocher une a une pour
                // le remonter en tete serait un travail, pas un geste.
                if let asset = page.pdfAssetID {
                    Button("Sélectionner tout ce PDF") {
                        isSelecting = true
                        selection = Set(pages.filter { $0.pdfAssetID == asset }.map(\.id))
                    }
                }
                Divider()
            }
            Menu("Intercalaire") {
                ForEach(PageTag.allCases, id: \.self) { tag in
                    Button(tag.label) { onTag(page, tag) }
                }
                if !page.tagToken.isEmpty {
                    Divider()
                    Button("Retirer") { onTag(page, nil) }
                }
            }
            Divider()
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
