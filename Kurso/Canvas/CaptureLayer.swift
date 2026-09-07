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
    let handle: CanvasHandle
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
                        let captured = strokes(in: selection)
                        captured.strokes.isEmpty ? onCancel() : onCapture(captured)
                    }
            )
        }
    }

    /// Les traits dont la majorite de la boite tombe dans la selection.
    ///
    /// La majorite plutot que le centre : sur une ecriture cursive, une ligne
    /// entiere peut etre un seul trait dont le centre echappe au cercle. Et
    /// plutot que la simple intersection, qui embarquerait la ligne du dessus
    /// des qu'on la frole.
    private func strokes(in selection: CGRect) -> PKDrawing {
        // Coordonnees de vue -> coordonnees de dessin, via le defilement et le
        // zoom reels. Sans ca, une selection tracee sur un canevas defile
        // designe la mauvaise zone.
        let target = handle.toDrawing(selection)

        let selected = drawing.strokes.filter { stroke in
            let box = stroke.renderBounds
            let area = box.width * box.height
            guard area > 0 else { return target.contains(CGPoint(x: box.midX, y: box.midY)) }
            let overlap = box.intersection(target)
            guard !overlap.isNull else { return false }
            return (overlap.width * overlap.height) / area >= 0.5
        }
        return PKDrawing(strokes: selected)
    }
}
#endif
