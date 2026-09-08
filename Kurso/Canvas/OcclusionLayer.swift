import SwiftUI
import SwiftData
import KursoModels

/// Masquage d'une zone de diapo (§11, etape 2).
///
/// « Masquer pour reviser » cree une carte a occlusion : la zone cachee devient
/// la question, la diapo entiere la reponse. C'est le geste qui transforme un
/// polycopie en revision, sans generation automatique — le §12 l'interdit.
struct OcclusionLayer: View {
    let page: Page
    let pageIndex: Int
    var onFinish: () -> Void

    @Environment(\.modelContext) private var context
    @State private var current: CGRect?

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Color.black.opacity(0.05)

                // Les zones enregistrees sont en fractions : on les ramene a
                // la taille affichee avant de les dessiner.
                ForEach(existingRects, id: \.self) { fraction in
                    mask(scaled(fraction, to: geo.size), in: geo.size, isNew: false)
                }
                if let current {
                    mask(current, in: geo.size, isNew: true)
                }

                VStack {
                    Spacer()
                    Text(existingRects.isEmpty
                         ? "Trace un rectangle sur ce que tu veux cacher"
                         : "\(existingRects.count) zone(s) masquée(s)")
                        .font(KFont.body(12.5, weight: .extraBold))
                        .foregroundStyle(K.paperAlt)
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .background(K.ink, in: Capsule())
                        .padding(.bottom, 18)
                }
                .frame(maxWidth: .infinity)
            }
            #if DEBUG
            .task {
                // Rejoue le geste de masquage sans passer par le doigt.
                guard ProcessInfo.processInfo.arguments.contains("-simulateOcclusion") else { return }
                try? await Task.sleep(for: .seconds(2))
                print("[MASQUE] creation d'une zone…")
                createCard(CGRect(x: 60, y: 80, width: 220, height: 140), in: geo.size)
                print("[MASQUE] zone creee, total=\(existingRects.count)")
            }
            #endif
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { value in
                        current = CGRect(
                            x: min(value.startLocation.x, value.location.x),
                            y: min(value.startLocation.y, value.location.y),
                            width: abs(value.location.x - value.startLocation.x),
                            height: abs(value.location.y - value.startLocation.y)
                        )
                    }
                    .onEnded { _ in
                        if let rect = current, rect.width > 20, rect.height > 20 {
                            createCard(rect, in: geo.size)
                        }
                        current = nil
                    }
            )
        }
    }

    private func mask(_ rect: CGRect, in size: CGSize, isNew: Bool) -> some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(isNew ? K.brand.opacity(0.35) : K.reward)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(K.ink, lineWidth: 3)
            )
            .frame(width: rect.width, height: rect.height)
            .offset(x: rect.minX, y: rect.minY)
    }

    /// Les zones deja creees, ramenees a la taille affichee.
    private var existingRects: [CGRect] {
        (page.cards ?? [])
            .filter { $0.kind == .imageOcclusion }
            .compactMap(\.occlusionRect)
    }

    private func scaled(_ fraction: CGRect, to size: CGSize) -> CGRect {
        CGRect(
            x: fraction.minX * size.width,
            y: fraction.minY * size.height,
            width: fraction.width * size.width,
            height: fraction.height * size.height
        )
    }

    /// Le rectangle est stocke en fractions de la page, pas en points : la
    /// meme carte doit se relire sur un iPad et sur un Mac, a des tailles
    /// differentes.
    private func createCard(_ rect: CGRect, in size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        let card = Card(question: "Que cache cette zone ?", kind: .imageOcclusion, dueAt: .now)
        card.occlusionRect = CGRect(
            x: rect.minX / size.width,
            y: rect.minY / size.height,
            width: rect.width / size.width,
            height: rect.height / size.height
        )
        card.page = page
        context.insert(card)
        try? context.save()
    }
}
