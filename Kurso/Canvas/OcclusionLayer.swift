#if os(iOS)
import SwiftUI
import SwiftData
import KursoCore
import KursoModels

/// Masquage d'une zone de diapo (§11, etape 2).
///
/// « Masquer pour reviser » cree une carte a occlusion : la zone cachee devient
/// la question, la diapo entiere la reponse. C'est le geste qui transforme un
/// polycopie en revision, sans generation automatique — le §12 l'interdit.
///
/// Les zones sont enregistrees en fractions DE LA DIAPO, jamais de l'ecran :
/// la diapo est posee dans le repere zoomable du canevas, et une fraction
/// d'ecran ne tombait pas au meme endroit d'un zoom a l'autre.
struct OcclusionLayer: View {
    let page: Page
    let pageIndex: Int
    /// Zoom et defilement du canevas, pour retrouver ou la diapo est posee.
    let viewport: PaperBackdrop.Viewport
    /// La diapo rendue : sa taille sert au reperage, son image part avec la
    /// carte pour qu'on puisse reviser sans rouvrir le PDF.
    let slideImage: CGImage?
    var onFinish: () -> Void

    @Environment(\.modelContext) private var context
    @State private var draft: CGRect?
    @State private var selected: Card?

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Assez visible pour qu'on sache qu'on est en mode masquage.
            Color.black.opacity(0.12)

            ForEach(existingCards, id: \.id) { card in
                if let rect = card.occlusionRect.map(toScreen) {
                    mask(rect, kind: card.id == selected?.id ? .selected : .saved)
                        .onTapGesture { selected = (selected?.id == card.id) ? nil : card }
                }
            }

            if let draft {
                mask(draft, kind: .draft)
                handle(for: draft)
            }

            toolbar
        }
        .contentShape(Rectangle())
        .gesture(drawOrMove)
    }

    // MARK: Le geste

    private var drawOrMove: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                // Un brouillon deja pose se deplace ; sinon on en trace un.
                if let current = draft, current.contains(value.startLocation) {
                    draft = current.offsetBy(dx: value.translation.width - lastMove.width,
                                             dy: value.translation.height - lastMove.height)
                    lastMove = value.translation
                    return
                }
                lastMove = .zero
                draft = CGRect(
                    x: min(value.startLocation.x, value.location.x),
                    y: min(value.startLocation.y, value.location.y),
                    width: abs(value.location.x - value.startLocation.x),
                    height: abs(value.location.y - value.startLocation.y)
                )
            }
            .onEnded { _ in lastMove = .zero }
    }

    /// Poignee de redimensionnement, en bas a droite du brouillon.
    private func handle(for rect: CGRect) -> some View {
        Circle()
            .fill(K.paperAlt)
            .overlay(Circle().strokeBorder(K.ink, lineWidth: 3))
            .frame(width: 28, height: 28)
            .offset(x: rect.maxX - 14, y: rect.maxY - 14)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        draft = CGRect(x: rect.minX, y: rect.minY,
                                       width: max(24, value.location.x - rect.minX),
                                       height: max(24, value.location.y - rect.minY))
                    }
            )
    }

    @State private var lastMove: CGSize = .zero

    // MARK: Les rectangles

    private enum Kind { case draft, saved, selected }

    private func mask(_ rect: CGRect, kind: Kind) -> some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(kind == .draft ? K.brand.opacity(0.45) : K.reward)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(kind == .selected ? K.brand : K.ink,
                                  lineWidth: kind == .selected ? 4 : 3)
            )
            .frame(width: max(rect.width, 1), height: max(rect.height, 1))
            .offset(x: rect.minX, y: rect.minY)
    }

    // MARK: La barre

    private var toolbar: some View {
        VStack {
            Spacer()
            HStack(spacing: 10) {
                if let selected {
                    Button("Supprimer cette zone") { delete(selected) }
                        .buttonStyle(StickerButtonStyle(kind: .secondary))
                } else if draft != nil {
                    Button("Annuler") { draft = nil }
                        .buttonStyle(StickerButtonStyle(kind: .secondary))
                    Button("Créer la carte") { confirm() }
                        .buttonStyle(StickerButtonStyle(kind: .confirm))
                } else {
                    Text(existingCards.isEmpty
                         ? "Trace un rectangle sur ce que tu veux cacher"
                         : "\(existingCards.count) zone(s) masquée(s) · touche-en une pour la retirer")
                        .font(KFont.body(12.5, weight: .extraBold))
                        .foregroundStyle(K.paperAlt)
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .background(K.ink, in: Capsule())
                    Button("Terminer") { onFinish() }
                        .buttonStyle(StickerButtonStyle(kind: .primary))
                }
            }
            // Au-dessus de la palette PencilKit, qui flotte en bas et
            // masquait entierement cette barre.
            .padding(.bottom, 150)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Reperes

    /// La diapo telle qu'elle est posee a l'ecran, zoom compris.
    private var slideRect: CGRect {
        let pageRect = CGRect(x: -viewport.offset.x, y: -viewport.offset.y,
                              width: PaperBackdrop.pageWidth * viewport.zoom,
                              height: PaperBackdrop.pageHeight * viewport.zoom)
        guard let slideImage else { return pageRect }
        return PaperBackdrop.fitted(
            CGSize(width: slideImage.width, height: slideImage.height), into: pageRect)
    }

    private func toScreen(_ fraction: CGRect) -> CGRect {
        let s = slideRect
        return CGRect(x: s.minX + fraction.minX * s.width,
                      y: s.minY + fraction.minY * s.height,
                      width: fraction.width * s.width,
                      height: fraction.height * s.height)
    }

    private func toFraction(_ rect: CGRect) -> CGRect? {
        let s = slideRect
        guard s.width > 0, s.height > 0 else { return nil }
        return CGRect(x: (rect.minX - s.minX) / s.width,
                      y: (rect.minY - s.minY) / s.height,
                      width: rect.width / s.width,
                      height: rect.height / s.height)
    }

    private var existingCards: [Card] {
        (page.cards ?? [])
            .filter { $0.kind == .imageOcclusion && $0.occlusionRect != nil }

    }

    // MARK: Actions

    /// Rien n'est enregistre avant ce bouton : on veut pouvoir replacer la
    /// zone, la retailler, et seulement ensuite en faire une carte.
    private func confirm() {
        guard let draft, draft.width > 16, draft.height > 16,
              let fraction = toFraction(draft) else { return }
        let card = Card(question: "Que cache cette zone ?", kind: .imageOcclusion, dueAt: .now)
        card.occlusionRect = fraction
        card.imageData = Self.snapshot(slideImage)
        card.page = page
        context.insert(card)
        try? context.save()
        self.draft = nil
    }

    /// La diapo, reduite : une carte doit rester legere, elle part dans iCloud.
    private static func snapshot(_ image: CGImage?) -> Data? {
        guard let image else { return nil }
        let targetWidth: CGFloat = 1_200
        let scale = min(1, targetWidth / CGFloat(image.width))
        let size = CGSize(width: CGFloat(image.width) * scale,
                          height: CGFloat(image.height) * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1   // sinon l'ecran Retina double la taille demandee
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let reduced = renderer.image { context in
            context.cgContext.interpolationQuality = .high
            UIImage(cgImage: image).draw(in: CGRect(origin: .zero, size: size))
        }
        return reduced.jpegData(compressionQuality: 0.75)
    }

    private func delete(_ card: Card) {
        context.delete(card)
        try? context.save()
        selected = nil
    }
}
#endif
