import Foundation
import SwiftData
import KursoCore
import KursoModels

/// Propositions de devoirs pour une page (§5).
///
/// Rien n'est cree sans validation : la proposition s'affiche en marge, et
/// c'est l'etudiant qui tranche.
enum TaskProposals {

    @MainActor
    static func detect(for page: Page, context: ModelContext) -> [TaskDetector.Proposal] {
        let disabled = Set(
            ((try? context.fetch(FetchDescriptor<MarkerFeedback>())) ?? [])
                .filter(\.isDisabled)
                .map(\.marker)
        )
        // Le manuscrit reconnu et le markdown tape sont deux sources de la meme
        // page : un devoir note sur le Mac compte autant qu'un devoir ecrit.
        let sources = [page.recognizedText, page.markdown].filter { !$0.isEmpty }
        return sources.flatMap {
            TaskDetector.detect(in: $0, disabledMarkers: disabled)
        }
    }

    @MainActor
    static func accept(_ proposal: TaskDetector.Proposal, page: Page, context: ModelContext) {
        let assignment = Assignment(title: proposal.title, dueAt: proposal.dueAt, wasProposed: true)
        assignment.page = page
        context.insert(assignment)
        try? context.save()
    }

    /// Un refus incremente le compteur du marqueur. Au troisieme, il se tait.
    @MainActor
    static func reject(_ proposal: TaskDetector.Proposal, context: ModelContext) {
        let marker = proposal.marker
        let descriptor = FetchDescriptor<MarkerFeedback>(
            predicate: #Predicate { $0.marker == marker }
        )
        let feedback = (try? context.fetch(descriptor))?.first ?? {
            let new = MarkerFeedback(marker: marker)
            context.insert(new)
            return new
        }()
        feedback.rejections += 1
        try? context.save()
    }
}
