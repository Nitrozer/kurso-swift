#if os(iOS)
import SwiftUI
import KursoCore
import KursoModels

/// Deplacer et retailler les images posees sur la page.
///
/// Les cadres sont en fractions de page : ils tiennent donc au zoom, et le
/// masquage comme la capture les retrouvent au meme endroit.
struct ImagesLayer: View {
    let images: [PageImage]
    let viewport: PaperBackdrop.Viewport
    var onChange: (PageImage, CGRect) -> Void
    var onDelete: (PageImage) -> Void
    var onClose: () -> Void

    @State private var selected: UUID?
    @State private var draft: CGRect?
    @State private var lastTranslation: CGSize = .zero

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.opacity(0.08)

            ForEach(images, id: \.id) { item in
                let frame = onScreen(item)
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(item.id == selected ? K.brand : K.ink.opacity(0.35),
                                  style: StrokeStyle(lineWidth: item.id == selected ? 3 : 2,
                                                     dash: [8, 5]))
                    .frame(width: max(frame.width, 1), height: max(frame.height, 1))
                    .offset(x: frame.minX, y: frame.minY)
                    .contentShape(Rectangle())
                    .onTapGesture { selected = item.id; draft = nil }
                    .gesture(moveGesture(item))
            }

            if let item = current {
                handle(for: item)
            }

            toolbar
        }
        .contentShape(Rectangle())
    }

    private var current: PageImage? {
        images.first { $0.id == selected }
    }

    private func moveGesture(_ item: PageImage) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                if selected != item.id { selected = item.id; draft = nil }
                let base = draft ?? onScreen(item)
                let dx = value.translation.width - lastTranslation.width
                let dy = value.translation.height - lastTranslation.height
                lastTranslation = value.translation
                draft = base.offsetBy(dx: dx, dy: dy)
            }
            .onEnded { _ in
                lastTranslation = .zero
                commit(item)
            }
    }

    private func handle(for item: PageImage) -> some View {
        let frame = draft ?? onScreen(item)
        return Circle()
            .fill(K.paperAlt)
            .overlay(Circle().strokeBorder(K.ink, lineWidth: 3))
            .frame(width: 30, height: 30)
            .offset(x: frame.maxX - 15, y: frame.maxY - 15)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let base = draft ?? onScreen(item)
                        let ratio = base.height / max(base.width, 1)
                        let width = max(60, value.location.x - base.minX)
                        draft = CGRect(x: base.minX, y: base.minY,
                                       width: width, height: width * ratio)
                    }
                    .onEnded { _ in commit(item) }
            )
    }

    private var toolbar: some View {
        VStack {
            Spacer()
            HStack(spacing: 10) {
                if let item = current {
                    Button("Supprimer l'image") { onDelete(item); selected = nil; draft = nil }
                        .buttonStyle(StickerButtonStyle(kind: .secondary))
                } else {
                    Text("Touche une image pour la déplacer")
                        .font(KFont.body(12.5, weight: .extraBold))
                        .foregroundStyle(K.paperAlt)
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .background(K.ink, in: Capsule())
                }
                Button("Terminer") { onClose() }
                    .buttonStyle(StickerButtonStyle(kind: .primary))
            }
            // Au-dessus de la palette PencilKit, qui flotte en bas.
            .padding(.bottom, 150)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Reperes

    private var pageRect: CGRect {
        CGRect(x: -viewport.offset.x, y: -viewport.offset.y,
               width: PaperBackdrop.pageWidth * viewport.zoom,
               height: PaperBackdrop.pageHeight * viewport.zoom)
    }

    private func onScreen(_ item: PageImage) -> CGRect {
        let page = pageRect
        return CGRect(x: page.minX + item.x * page.width,
                      y: page.minY + item.y * page.height,
                      width: item.width * page.width,
                      height: item.height * page.height)
    }

    private func commit(_ item: PageImage) {
        guard let draft, let box = ImagePlacement.box(from: draft, in: pageRect) else { return }
        onChange(item, box)
        self.draft = nil
    }
}
#endif
