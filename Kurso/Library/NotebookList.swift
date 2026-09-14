import SwiftUI
import KursoCore
import KursoModels

/// Un cahier, dans l'ordre voulu.
///
/// Le §12 interdit les dossiers et les arborescences a creer a la main. Ici on
/// n'en cree aucun : le cahier reste la matiere, rangee par l'emploi du temps.
/// Ce qui se decide, c'est la SEQUENCE a l'interieur — une page ecrite, deux
/// diapos, une photo, puis la suite du cours.
struct NotebookList: View {
    let pages: [Page]
    var onOpen: (Page) -> Void
    var onDelete: (Page) -> Void
    var onMove: (Page, Int) -> Void
    /// Inserer un element a ce rang.
    var onInsert: (Kind, Double) -> Void

    enum Kind { case handwritten, pdf, image }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                inserter(at: PageOrdering.position(after: nil, before: pages.first?.position))
                ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                    row(page, index: index)
                    inserter(at: PageOrdering.position(
                        after: page.position,
                        before: index + 1 < pages.count ? pages[index + 1].position : nil))
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: Une ligne

    private func row(_ page: Page, index: Int) -> some View {
        HStack(spacing: 14) {
            PagePreview(page: page)
                .frame(width: 78, height: 58)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(K.ink.opacity(0.2), lineWidth: 1.5))

            VStack(alignment: .leading, spacing: 3) {
                Text(page.title.isEmpty ? "Page sans titre" : page.title)
                    .font(KFont.body(14, weight: .extraBold))
                    .foregroundStyle(K.ink)
                    .lineLimit(1)
                HStack(spacing: 7) {
                    Text(badge(page))
                        .font(KFont.mono(9))
                        .tracking(0.8)
                        .foregroundStyle(K.ink.opacity(0.75))
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .overlay(Capsule().strokeBorder(K.ink.opacity(0.3), lineWidth: 1.5))
                    MetaText(page.createdAt.formatted(.dateTime.day().month(.twoDigits)), size: 9.5)
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: 5) {
                arrow(up: true, enabled: index > 0) { onMove(page, index - 1) }
                arrow(up: false, enabled: index < pages.count - 1) { onMove(page, index + 1) }
            }

            Menu {
                Button("Ouvrir") { onOpen(page) }
                Button("Supprimer", role: .destructive) { onDelete(page) }
            } label: {
                Text("···")
                    .font(KFont.body(15, weight: .extraBold))
                    .foregroundStyle(K.ink)
                    .frame(width: 32, height: 30)
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(K.ink.opacity(0.25), lineWidth: 2))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sticker(fill: K.paperAlt, radius: 16)
        .contentShape(Rectangle())
        .onTapGesture { onOpen(page) }
    }

    private func arrow(up: Bool, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ChevronGlyph()
                .stroke(K.ink, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                .frame(width: 9, height: 9)
                .rotationEffect(.degrees(up ? 90 : -90))
                .frame(width: 28, height: 28)
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(K.ink.opacity(0.25), lineWidth: 2))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.3)
    }

    private func badge(_ page: Page) -> String {
        if page.pdfAssetID != nil { return "DIAPO" }
        if page.photo != nil { return "IMAGE" }
        return "MANUSCRITE"
    }

    // MARK: Le point d'insertion

    private func inserter(at position: Double) -> some View {
        Menu {
            Button("Page manuscrite") { onInsert(.handwritten, position) }
            Button("Pages d'un PDF") { onInsert(.pdf, position) }
            Button("Une image") { onInsert(.image, position) }
        } label: {
            HStack(spacing: 9) {
                Rectangle().fill(K.ink.opacity(0.12)).frame(height: 2)
                Text("+")
                    .font(KFont.body(14, weight: .extraBold))
                    .foregroundStyle(K.ink.opacity(0.55))
                    .frame(width: 26, height: 26)
                    .overlay(Circle().strokeBorder(K.ink.opacity(0.25), lineWidth: 2))
                Rectangle().fill(K.ink.opacity(0.12)).frame(height: 2)
            }
            .padding(.vertical, 9)
        }
        .menuStyle(.borderlessButton)
    }
}
