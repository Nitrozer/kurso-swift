#if os(iOS)
import SwiftUI
import KursoCore
import KursoModels

/// Les images posees sur la page : on les touche, on les deplace, on les
/// retaille. Sans mode a activer.
///
/// La couche ne bloque RIEN : seuls les cadres des images repondent au doigt,
/// tout le reste passe au canevas. C'est ce qui permet d'ecrire par-dessus une
/// image sans avoir a quitter quoi que ce soit.
struct ImagesLayer: View {
    let images: [PageImage]
    let viewport: PaperBackdrop.Viewport
    @Binding var selected: UUID?
    var onChange: (PageImage, CGRect) -> Void
    var onDelete: (PageImage) -> Void

    @State private var draft: CGRect?
    @State private var lastTranslation: CGSize = .zero

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Rien derriere : le stylet doit atteindre le canevas.
            Color.clear.allowsHitTesting(false)

            ForEach(images, id: \.id) { item in
                let frame = (item.id == selected ? draft : nil) ?? onScreen(item)
                ZStack(alignment: .topLeading) {
                    if item.id == selected {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(K.brand, lineWidth: 2.5)
                            .frame(width: max(frame.width, 1), height: max(frame.height, 1))
                            .offset(x: frame.minX, y: frame.minY)
                    }
                }
                .allowsHitTesting(false)

                // Seule la surface de l'image repond au doigt.
                Color.clear
                    .frame(width: max(frame.width, 1), height: max(frame.height, 1))
                    .offset(x: frame.minX, y: frame.minY)
                    .contentShape(Rectangle())
                    .onTapGesture { selected = (selected == item.id) ? nil : item.id }
                    .gesture(moveGesture(item))
            }

            if let item = currentImage {
                handle(for: item)
                deleteBadge(for: item)
            }
        }
    }

    private var currentImage: PageImage? {
        images.first { $0.id == selected }
    }

    // MARK: Gestes

    private func moveGesture(_ item: PageImage) -> some Gesture {
        DragGesture(minimumDistance: 6)
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

    /// Poignee en bas a droite. Le rapport de forme est conserve : une image
    /// etiree ne ressemble a rien.
    private func handle(for item: PageImage) -> some View {
        let frame = draft ?? onScreen(item)
        return Circle()
            .fill(K.paperAlt)
            .overlay(Circle().strokeBorder(K.brand, lineWidth: 3))
            .frame(width: 26, height: 26)
            .offset(x: frame.maxX - 13, y: frame.maxY - 13)
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

    private func deleteBadge(for item: PageImage) -> some View {
        let frame = draft ?? onScreen(item)
        return Button { onDelete(item); selected = nil; draft = nil } label: {
            CrossGlyph()
                .stroke(K.paperAlt, style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                .frame(width: 10, height: 10)
                .frame(width: 26, height: 26)
                .background(K.ink, in: Circle())
        }
        .buttonStyle(.plain)
        .offset(x: frame.minX - 13, y: frame.minY - 13)
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
