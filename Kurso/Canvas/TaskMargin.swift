import SwiftUI
import SwiftData
import KursoCore
import KursoModels
import PencilKit

/// La marge des propositions de devoirs (§5).
///
/// Elle n'apparait que quand il y a quelque chose a proposer : une marge vide
/// prendrait de la place sur le canevas pour rien.
struct TaskMargin: View {
    let page: Page
    @Environment(\.modelContext) private var context
    @State private var proposals: [TaskDetector.Proposal] = []

    var body: some View {
        Group {
            if !proposals.isEmpty || !capturedCards.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        if !proposals.isEmpty {
                            MetaText("Reperé dans tes notes")
                            ForEach(proposals, id: \.title) { proposal in
                                card(proposal)
                            }
                        }
                        if !capturedCards.isEmpty {
                            MetaText("Cartes capturées · \(capturedCards.count)")
                                .padding(.top, proposals.isEmpty ? 0 : 8)
                            ForEach(capturedCards) { card in
                                capturedCard(card)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                }
                .scrollIndicators(.hidden)
                .padding(16)
                .frame(width: 240)
                .background(K.paper)
                .overlay(alignment: .leading) {
                    Rectangle().fill(K.ink).frame(width: 3)
                }
            }
        }
        .task(id: page.recognizedText) { refresh() }
    }

    /// Les cartes nees de cette page, verso compris — le trace, pas un texte.
    private var capturedCards: [Card] {
        (page.cards ?? []).sorted { $0.dueAt < $1.dueAt }
    }

    private func capturedCard(_ card: Card) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(card.question)
                .font(KFont.body(12.5, weight: .extraBold))
                .foregroundStyle(K.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let image = versoImage(card) {
                image.resizable().scaledToFit().frame(maxHeight: 54)
            } else if card.kind == .imageOcclusion {
                MetaText("Zone masquée")
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sticker(fill: K.paperAlt, radius: 14, state: .done)
    }

    private func versoImage(_ card: Card) -> Image? {
        guard let data = card.answerDrawing,
              let drawing = try? PKDrawing(data: data),
              !drawing.bounds.isEmpty else { return nil }
        let rendered = drawing.image(from: drawing.bounds, scale: 2)
        #if canImport(UIKit)
        return Image(uiImage: rendered)
        #else
        return Image(nsImage: rendered)
        #endif
    }

    private func card(_ proposal: TaskDetector.Proposal) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("PROPOSÉ")
                    .font(KFont.body(10, weight: .extraBold))
                    .tracking(0.8)
                    .foregroundStyle(K.ink)
                    .padding(.horizontal, 9).padding(.vertical, 3)
                    .background(K.reward, in: Capsule())
                    .overlay(Capsule().strokeBorder(K.ink, lineWidth: 2.5))
                Spacer(minLength: 0)
            }

            Text(proposal.title)
                .font(KFont.body(13, weight: .extraBold))
                .foregroundStyle(K.ink)
                .fixedSize(horizontal: false, vertical: true)

            MetaText(proposal.dueAt.formatted(.dateTime.day().month(.abbreviated).hour().minute()))

            HStack(spacing: 8) {
                Button {
                    TaskProposals.accept(proposal, page: page, context: context)
                    remove(proposal)
                } label: {
                    Text("Ajouter")
                        .font(KFont.body(12, weight: .extraBold))
                        .foregroundStyle(K.paperAlt)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(K.success, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .strokeBorder(K.ink, lineWidth: 2.5))
                }
                .buttonStyle(.plain)

                Button {
                    TaskProposals.reject(proposal, context: context)
                    remove(proposal)
                } label: {
                    Text("Non")
                        .font(KFont.body(12, weight: .extraBold))
                        .foregroundStyle(K.ink)
                        .padding(.horizontal, 13).padding(.vertical, 7)
                        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .strokeBorder(K.ink, lineWidth: 2.5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(13)
        .sticker(fill: K.paperAlt, radius: 14)
    }

    private func refresh() {
        proposals = TaskProposals.detect(for: page, context: context)
    }

    private func remove(_ proposal: TaskDetector.Proposal) {
        proposals.removeAll { $0.title == proposal.title }
    }
}
