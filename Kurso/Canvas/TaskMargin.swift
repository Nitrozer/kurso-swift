import SwiftUI
import SwiftData
import KursoCore
import KursoModels

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
            if !proposals.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    MetaText("Reperé dans tes notes")
                    ForEach(proposals, id: \.title) { proposal in
                        card(proposal)
                    }
                    Spacer(minLength: 0)
                }
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
