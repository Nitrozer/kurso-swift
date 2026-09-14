#if os(iOS)
import SwiftUI

/// Selection d'un morceau de la page pour en faire une image.
///
/// Sert a decouper un bout de diapo ou de photo — un schema, une formule —
/// et a le garder tel quel sur une carte. On ne retape rien : c'est le §4,
/// « le verso n'est jamais reecrit ».
struct RegionCaptureLayer: View {
    var onCapture: (CGRect) -> Void
    var onCancel: () -> Void

    @State private var rect: CGRect?

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.opacity(0.12)

            if let rect {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(K.brand.opacity(0.16))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(K.brand, style: StrokeStyle(lineWidth: 3, dash: [8, 5])))
                    .frame(width: max(rect.width, 1), height: max(rect.height, 1))
                    .offset(x: rect.minX, y: rect.minY)
            }

            VStack {
                Spacer()
                HStack(spacing: 10) {
                    if let rect, rect.width > 24, rect.height > 24 {
                        Button("Annuler") { self.rect = nil; onCancel() }
                            .buttonStyle(StickerButtonStyle(kind: .secondary))
                        Button("Garder ce morceau") { onCapture(rect) }
                            .buttonStyle(StickerButtonStyle(kind: .confirm))
                    } else {
                        Text("Entoure le morceau à garder")
                            .font(KFont.body(12.5, weight: .extraBold))
                            .foregroundStyle(K.paperAlt)
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .background(K.ink, in: Capsule())
                        Button("Annuler") { onCancel() }
                            .buttonStyle(StickerButtonStyle(kind: .secondary))
                    }
                }
                // Au-dessus de la palette PencilKit, qui flotte en bas.
                .padding(.bottom, 150)
            }
            .frame(maxWidth: .infinity)
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 6)
                .onChanged { value in
                    rect = CGRect(
                        x: min(value.startLocation.x, value.location.x),
                        y: min(value.startLocation.y, value.location.y),
                        width: abs(value.location.x - value.startLocation.x),
                        height: abs(value.location.y - value.startLocation.y)
                    )
                }
        )
    }
}
#endif
