import Foundation
import SwiftData
import KursoCore
import KursoModels

/// La saison en cours, et la date d'examen qui pilote le mode partiel (§9).
///
/// Elle est creee a la demande : un etudiant qui n'a pas encore d'examen
/// prevu n'a pas besoin qu'on lui fabrique une saison vide.
enum SeasonStore {

    @MainActor
    static func current(_ context: ModelContext) -> Season? {
        let open = (try? context.fetch(FetchDescriptor<Season>()))?
            .filter { $0.closedAt == nil }
        return open?.sorted { $0.startsAt > $1.startsAt }.first
    }

    @MainActor
    static func ensure(_ context: ModelContext) -> Season {
        if let existing = current(context) { return existing }
        let season = Season()
        season.name = "Semestre en cours"
        season.startsAt = .now
        context.insert(season)
        try? context.save()
        return season
    }

    /// Le semestre precedent s'est-il fini avec des pages rouges ?
    /// Il y a alors plus a rattraper, et le mode partiel s'ouvre plus tot.
    @MainActor
    static func previousWasHard(_ context: ModelContext) -> Bool {
        let closed = (try? context.fetch(FetchDescriptor<Season>()))?
            .filter { $0.closedAt != nil }
            .sorted { ($0.closedAt ?? .distantPast) > ($1.closedAt ?? .distantPast) }
        guard let last = closed?.first, let percent = last.finalAcquiredPercent else { return false }
        return percent < 0.5
    }

    @MainActor
    static func isExamMode(_ context: ModelContext) -> Bool {
        ExamMode.isActive(examDate: current(context)?.examDate,
                          hadRedPages: previousWasHard(context))
    }
}
