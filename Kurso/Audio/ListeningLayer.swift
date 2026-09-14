#if os(iOS)
import SwiftUI
import KursoCore

/// Mode ecoute : toucher un mot rejoue ce que le prof disait a ce moment-la.
///
/// Les traits horodates sont montres en pastilles : sans reperes visibles, on
/// touche au hasard et on croit que rien ne marche.
struct ListeningLayer: View {
    let marks: [AudioSync.Mark]
    let viewport: PaperBackdrop.Viewport
    var onPick: (AudioSync.Mark) -> Void
    var onClose: () -> Void

    /// Rayon de recherche, en points de page.
    private let radius: CGFloat = 90

    @State private var played: UUID?

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.brandWash

            ForEach(marks, id: \.strokeID) { mark in
                let point = onScreen(mark.anchor)
                Circle()
                    .fill(mark.strokeID == played ? K.brand : K.brand.opacity(0.28))
                    .frame(width: 10, height: 10)
                    .offset(x: point.x - 5, y: point.y - 5)
                    .allowsHitTesting(false)
            }

            VStack {
                Spacer()
                HStack(spacing: 10) {
                    Text("Touche un mot pour réentendre")
                        .font(KFont.body(12.5, weight: .extraBold))
                        .foregroundStyle(K.paperAlt)
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .background(K.ink, in: Capsule())
                    Button("Terminer") { onClose() }
                        .buttonStyle(StickerButtonStyle(kind: .primary))
                }
                .padding(.bottom, 150)
            }
            .frame(maxWidth: .infinity)
        }
        .contentShape(Rectangle())
        .onTapGesture { location in
            let inPage = inPageSpace(location)
            guard let mark = AudioSync.nearest(to: inPage, among: marks, within: radius) else { return }
            played = mark.strokeID
            onPick(mark)
        }
    }

    // MARK: Reperes

    private func onScreen(_ pagePoint: CGPoint) -> CGPoint {
        CGPoint(x: pagePoint.x * viewport.zoom - viewport.offset.x,
                y: pagePoint.y * viewport.zoom - viewport.offset.y)
    }

    private func inPageSpace(_ screenPoint: CGPoint) -> CGPoint {
        let zoom = max(viewport.zoom, 0.01)
        return CGPoint(x: (screenPoint.x + viewport.offset.x) / zoom,
                       y: (screenPoint.y + viewport.offset.y) / zoom)
    }
}

private extension Color {
    /// Un voile discret : on doit continuer a lire ses notes en dessous.
    static var brandWash: Color { K.brand.opacity(0.06) }
}
#endif
