#if os(iOS)
import SwiftUI
import PencilKit

/// Capture d'une carte au geste (§11, etape 3).
///
/// On entoure une partie de son ecriture : les traits selectionnes deviennent
/// le verso, tels quels. Le §4 l'exige — « le verso n'est jamais reecrit,
/// "inser°" reste "inser°" » — donc on garde le PKDrawing, pas du texte reconnu.
struct CaptureLayer: View {
    let drawing: PKDrawing
    /// Rend les traits entoures, ou rien si la selection est vide.
    var onCapture: (PKDrawing) -> Void
    var onCancel: () -> Void

    @State private var rect: CGRect?

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Color.black.opacity(0.04)

                if let rect {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(K.brand.opacity(0.16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(K.brand, style: StrokeStyle(lineWidth: 3, dash: [8, 5]))
                        )
                        .frame(width: rect.width, height: rect.height)
                        .offset(x: rect.minX, y: rect.minY)
                }

                VStack {
                    Spacer()
                    Text("Entoure ce que tu veux retenir")
                        .font(KFont.body(12.5, weight: .extraBold))
                        .foregroundStyle(K.paperAlt)
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .background(K.ink, in: Capsule())
                        .padding(.bottom, 18)
                }
                .frame(maxWidth: .infinity)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { value in
                        rect = CGRect(
                            x: min(value.startLocation.x, value.location.x),
                            y: min(value.startLocation.y, value.location.y),
                            width: abs(value.location.x - value.startLocation.x),
                            height: abs(value.location.y - value.startLocation.y)
                        )
                    }
                    .onEnded { _ in
                        defer { rect = nil }
                        guard let selection = rect, selection.width > 20, selection.height > 20 else { return }
                        let captured = strokes(in: selection, viewSize: geo.size)
                        captured.strokes.isEmpty ? onCancel() : onCapture(captured)
                    }
            )
        }
    }

    /// Les traits dont le centre tombe dans la selection.
    ///
    /// Le centre plutot que l'intersection : entourer une ligne ne doit pas
    /// embarquer la moitie de celle du dessus.
    private func strokes(in selection: CGRect, viewSize: CGSize) -> PKDrawing {
        let bounds = drawing.bounds
        guard !bounds.isEmpty, viewSize.width > 0, viewSize.height > 0 else { return PKDrawing() }

        // Le canevas defile : la selection est en coordonnees de vue, les traits
        // en coordonnees de dessin. On passe par les fractions.
        let scaleX = bounds.width / viewSize.width
        let scaleY = bounds.height / viewSize.height
        let inDrawing = CGRect(
            x: bounds.minX + selection.minX * scaleX,
            y: bounds.minY + selection.minY * scaleY,
            width: selection.width * scaleX,
            height: selection.height * scaleY
        )

        let selected = drawing.strokes.filter { stroke in
            let box = stroke.renderBounds
            return inDrawing.contains(CGPoint(x: box.midX, y: box.midY))
        }
        return PKDrawing(strokes: selected)
    }
}
#endif
