#if os(iOS)
import SwiftUI

/// Reglage de la taille et de la position d'une image posee sur la page.
///
/// Le rectangle est rendu en fractions de page : il reste donc au meme endroit
/// quel que soit le zoom, et le masquage comme la capture s'y retrouvent —
/// tous passent par `PaperBackdrop.placement`.
struct PhotoAdjustLayer: View {
    /// Le cadre actuel, a l'ecran.
    let current: CGRect
    /// Rend le nouveau cadre, a l'ecran.
    var onChange: (CGRect) -> Void
    var onReset: () -> Void
    var onDone: () -> Void

    @State private var draft: CGRect?
    @State private var lastTranslation: CGSize = .zero

    private var frame: CGRect { draft ?? current }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.opacity(0.10)

            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(K.brand, style: StrokeStyle(lineWidth: 3, dash: [9, 6]))
                .frame(width: max(frame.width, 1), height: max(frame.height, 1))
                .offset(x: frame.minX, y: frame.minY)

            handle
            toolbar
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 4)
                .onChanged { value in
                    let base = draft ?? current
                    let dx = value.translation.width - lastTranslation.width
                    let dy = value.translation.height - lastTranslation.height
                    lastTranslation = value.translation
                    draft = base.offsetBy(dx: dx, dy: dy)
                }
                .onEnded { _ in
                    lastTranslation = .zero
                    if let draft { onChange(draft) }
                }
        )
    }

    /// Poignee en bas a droite : elle retaille sans deformer.
    private var handle: some View {
        Circle()
            .fill(K.paperAlt)
            .overlay(Circle().strokeBorder(K.ink, lineWidth: 3))
            .frame(width: 32, height: 32)
            .offset(x: frame.maxX - 16, y: frame.maxY - 16)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let base = draft ?? current
                        let ratio = base.height / max(base.width, 1)
                        let width = max(80, value.location.x - base.minX)
                        draft = CGRect(x: base.minX, y: base.minY,
                                       width: width, height: width * ratio)
                    }
                    .onEnded { _ in if let draft { onChange(draft) } }
            )
    }

    private var toolbar: some View {
        VStack {
            Spacer()
            HStack(spacing: 10) {
                Button("Pleine largeur") { draft = nil; onReset() }
                    .buttonStyle(StickerButtonStyle(kind: .secondary))
                Button("Terminer") { onDone() }
                    .buttonStyle(StickerButtonStyle(kind: .primary))
            }
            // Au-dessus de la palette PencilKit, qui flotte en bas.
            .padding(.bottom, 150)
        }
        .frame(maxWidth: .infinity)
    }
}
#endif
