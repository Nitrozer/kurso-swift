import Foundation
import SwiftData
import KursoCore
import KursoModels

/// Rattache une page a son cours (§6).
///
/// « C'est ce qui construit la carte sans aucune saisie » : ouvrir une page
/// pendant un creneau la range dans la bonne matiere et la relie a la
/// precedente. L'etudiant ne choisit rien, ne classe rien.
enum PageAttachment {

    /// Rattache la page si un creneau est en cours. Ne fait rien sinon : une
    /// page ecrite un dimanche soir reste sans matiere, ce qui est correct.
    @MainActor
    @discardableResult
    static func attach(_ page: Page, at date: Date = .now, context: ModelContext) -> Course? {
        let slots = (try? context.fetch(FetchDescriptor<TimeSlot>())) ?? []
        guard !slots.isEmpty else { return nil }

        let candidates = slots.map {
            SlotMatcher.Slot(id: $0.id, start: $0.start, end: $0.end)
        }
        guard let match = SlotMatcher.slotInProgress(at: date, among: candidates),
              let slot = slots.first(where: { $0.id == match.id }),
              let course = slot.course
        else { return nil }

        page.course = course
        page.sessionEnd = slot.end
        page.previousPage = lastPage(of: course, before: page, context: context)
        return course
    }

    /// La derniere page de la meme matiere : c'est cette chaine qui devient une
    /// arete de la carte du semestre.
    @MainActor
    private static func lastPage(of course: Course, before page: Page, context: ModelContext) -> Page? {
        let courseID = course.id
        let createdAt = page.createdAt
        var descriptor = FetchDescriptor<Page>(
            predicate: #Predicate { candidate in
                candidate.course?.id == courseID && candidate.createdAt < createdAt
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }
}
