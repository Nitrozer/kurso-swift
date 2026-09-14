#if os(iOS)
import SwiftUI
import PDFKit
import KursoCore

/// Un fichier choisi, en attente qu'on decide quelles pages garder.
struct PickedPDF: Identifiable {
    let url: URL
    var id: String { url.path }
}

/// Choix des diapos a deposer dans le cahier.
///
/// Un polycopie fait souvent quatre-vingts pages dont on ne suit qu'un
/// chapitre : les deposer toutes noierait les notes manuscrites sous des
/// diapos qu'on n'ouvrira jamais.
struct PDFPagePicker: View {
    let url: URL
    var onCancel: () -> Void
    var onConfirm: (IndexSet) -> Void

    @State private var thumbnails: [CGImage?] = []
    @State private var selected: IndexSet = []
    @State private var isLoading = true

    private let columns = [GridItem(.adaptive(minimum: 128), spacing: 14)]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if thumbnails.isEmpty {
                EmptyState(title: "PDF illisible",
                           message: "Ce fichier n'a pas pu être ouvert.")
                    .frame(maxHeight: .infinity)
            } else {
                grid
            }
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(K.paper)
        .task { await load() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            MetaText(url.deletingPathExtension().lastPathComponent.uppercased())
            DisplayText("Quelles pages garder ?", size: 28)
        }
        .padding(.horizontal, 28)
        .padding(.top, 26)
        .padding(.bottom, 16)
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(thumbnails.indices, id: \.self) { index in
                    thumbnail(index)
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
    }

    private func thumbnail(_ index: Int) -> some View {
        let isOn = selected.contains(index)
        return Button {
            if isOn { selected.remove(index) } else { selected.insert(index) }
        } label: {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    Group {
                        if let image = thumbnails[index] {
                            Image(decorative: image, scale: 1).resizable().scaledToFit()
                        } else {
                            Color.white
                        }
                    }
                    .frame(height: 165)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    CheckBadge(kind: .task, isChecked: isOn, size: 22)
                        .padding(7)
                }
                Text("\(index + 1)")
                    .font(KFont.mono(10))
                    .foregroundStyle(K.inkSoft)
            }
            .padding(7)
            .background(isOn ? K.brand.opacity(0.1) : .clear,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(isOn ? K.brand : K.ink.opacity(0.18), lineWidth: isOn ? 3 : 2))
        }
        .buttonStyle(.plain)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button(selected.count == thumbnails.count ? "Tout décocher" : "Tout cocher") {
                selected = selected.count == thumbnails.count
                    ? []
                    : IndexSet(thumbnails.indices)
            }
            .buttonStyle(StickerButtonStyle(kind: .secondary))
            .disabled(thumbnails.isEmpty)

            Spacer(minLength: 0)

            Button("Annuler") { onCancel() }
                .buttonStyle(StickerButtonStyle(kind: .secondary))
            Button(label) { onConfirm(selected) }
                .buttonStyle(StickerButtonStyle(kind: .primary))
                .disabled(selected.isEmpty)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 22)
        .padding(.top, 8)
    }

    private var label: String {
        selected.count <= 1 ? "Déposer cette page" : "Déposer \(selected.count) pages"
    }

    /// Les apercus, rendus hors du fil principal : un polycopie epais bloquerait
    /// l'interface le temps de tout rasteriser.
    private func load() async {
        let source = url
        let rendered: [CGImage?] = await Task.detached(priority: .userInitiated) {
            let needsAccess = source.startAccessingSecurityScopedResource()
            defer { if needsAccess { source.stopAccessingSecurityScopedResource() } }
            guard let document = PDFDocument(url: source) else { return [] }
            // Le meme moteur que partout ailleurs : le rendu maison de cette
            // vue retournait les pages, l'origine d'un contexte UIKit etant
            // en haut et celle d'un PDF en bas.
            return (0..<document.pageCount).map {
                PDFStore.render(at: source, pageIndex: $0, width: 300)
            }
        }.value
        thumbnails = rendered
        selected = IndexSet(rendered.indices)   // tout coche par defaut
        isLoading = false
    }
}
#endif
