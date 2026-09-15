import Foundation
import SwiftData
import KursoCore
import KursoModels

/// La photographie d'avant-partiel, et le retour sur copie qui s'en sert.
enum ExamPaperStore {

    /// On photographie a partir de J-1, et une seule fois par partiel.
    static let snapshotWindow: TimeInterval = 86_400

    /// Prend la photo si le partiel est demain et qu'elle n'existe pas.
    ///
    /// Silencieuse : l'etudiant n'a pas a savoir que ca se passe, et surtout
    /// pas la veille d'un examen.
    @MainActor
    @discardableResult
    static func snapshotIfNeeded(_ context: ModelContext, now: Date = .now) -> Int {
        guard let season = SeasonStore.current(context), let exam = season.examDate else { return 0 }
        let remaining = exam.timeIntervalSince(now)
        guard remaining > 0, remaining <= snapshotWindow else { return 0 }

        let existing = (try? context.fetch(FetchDescriptor<ExamSnapshot>())) ?? []
        guard !existing.contains(where: { $0.examDate == exam }) else { return 0 }

        let pages = (try? context.fetch(FetchDescriptor<Page>())) ?? []
        var taken = 0
        for page in pages where page.course?.archivedAt == nil {
            let cards = page.cards ?? []
            let shot = ExamSnapshot()
            shot.pageID = page.id
            shot.pageTitle = page.title
            shot.stateRaw = Freshness.state(
                cards: cards.map { Freshness.CardState(dueAt: $0.dueAt, interval: $0.interval) },
                now: now
            ).rawValue
            shot.daysSinceReview = daysSinceReview(cards, now: now)
            shot.takenAt = now
            shot.examDate = exam
            context.insert(shot)
            taken += 1
        }
        try? context.save()
        return taken
    }

    /// Jours depuis la derniere revision : la carte la plus recemment vue
    /// donne le compte, puisqu'elle date la derniere visite de la page.
    private static func daysSinceReview(_ cards: [Card], now: Date) -> Int {
        let intervals = cards.map { $0.dueAt.addingTimeInterval(-Double($0.interval) * 86_400) }
        guard let last = intervals.max() else { return 0 }
        return max(0, Int(now.timeIntervalSince(last) / 86_400))
    }

    /// Les ratés d'une copie, enrichis de la photo d'avant-partiel.
    @MainActor
    static func misses(for paper: ExamPaper, context: ModelContext) -> [ExamReview.Miss] {
        let shots = ((try? context.fetch(FetchDescriptor<ExamSnapshot>())) ?? [])
            .filter { $0.examDate == paper.examDate }
        let byPage = Dictionary(shots.map { ($0.pageID, $0) }, uniquingKeysWith: { a, _ in a })

        return paper.misses.map { stored in
            let shot = stored.pageID.flatMap { byPage[$0] }
            return ExamReview.Miss(
                id: stored.id,
                label: stored.label,
                points: stored.points,
                kind: stored.kindRaw == "courseQuestion" ? .courseQuestion : .exercise,
                stateAtExam: shot.flatMap { Freshness.State(rawValue: $0.stateRaw) },
                daysSinceReview: shot?.daysSinceReview,
                pageID: stored.pageID
            )
        }
    }

    /// Le titre de page photographie, pour l'afficher a cote du raté.
    @MainActor
    static func pageTitle(_ pageID: UUID?, paper: ExamPaper, context: ModelContext) -> String? {
        guard let pageID else { return nil }
        let shots = ((try? context.fetch(FetchDescriptor<ExamSnapshot>())) ?? [])
            .filter { $0.examDate == paper.examDate && $0.pageID == pageID }
        return shots.first?.pageTitle
    }

    /// La copie du dernier partiel, s'il y en a une.
    @MainActor
    static func latest(_ context: ModelContext) -> ExamPaper? {
        ((try? context.fetch(FetchDescriptor<ExamPaper>())) ?? [])
            .sorted { $0.createdAt > $1.createdAt }
            .first
    }
}
