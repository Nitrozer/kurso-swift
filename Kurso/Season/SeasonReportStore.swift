import Foundation
import SwiftData
import KursoCore
import KursoModels

/// Rassemble le releve de fin de semestre, et le fige a la cloture.
enum SeasonReportStore {

    /// Les pages du semestre en cours : tout ce qui n'est pas encore archive.
    ///
    /// On ne filtre PAS sur `createdAt >= season.startsAt` : rien ne garantit
    /// qu'une saison soit ouverte avant la premiere page — elle est creee a la
    /// demande — et le releve se retrouvait alors vide. Ce qui delimite un
    /// semestre, c'est l'archivage, pas une date.
    @MainActor
    static func pages(_ context: ModelContext, season: Season) -> [Page] {
        let all = (try? context.fetch(FetchDescriptor<Page>())) ?? []
        return all
            .filter { $0.course?.archivedAt == nil }
            .sorted { $0.createdAt < $1.createdAt }
    }

    /// La saison ouverte, apres cloture par exemple.
    @MainActor
    static func current(_ context: ModelContext) -> Season? { SeasonStore.current(context) }

    /// Les cahiers du semestre en cours.
    @MainActor
    static func courses(_ context: ModelContext) -> [Course] {
        let all = (try? context.fetch(FetchDescriptor<Course>())) ?? []
        return all.filter { $0.archivedAt == nil }
    }

    @MainActor
    static func report(_ context: ModelContext, season: Season, now: Date = .now) -> SeasonReport.Report {
        let player = PlayerStore.current(context)

        let inputs = pages(context, season: season).map { page -> SeasonReport.PageInput in
            let cards = page.cards ?? []
            return SeasonReport.PageInput(
                writingSeconds: page.writingSeconds,
                cards: cards.map { Freshness.CardState(dueAt: $0.dueAt, interval: $0.interval) },
                lapses: cards.reduce(0) { $0 + $1.lapses }
            )
        }

        // Les revisions comptent depuis l'ouverture de la saison : elles,
        // au moins, sont datees jour par jour.
        let days = (try? context.fetch(FetchDescriptor<DailyActivity>())) ?? []
        let opened = Calendar.current.startOfDay(for: season.startsAt)
        let reviewed = days
            .filter { $0.day >= opened }
            .reduce(0) { $0 + $1.cardsReviewed }

        return SeasonReport.make(
            pages: inputs,
            cardsReviewed: reviewed,
            longestStreak: player.recordStreak,
            level: player.level,
            now: now
        )
    }

    /// Clot le semestre et en ouvre un neuf.
    ///
    /// Le releve est **fige** ici : le §1 le stocke sur la saison parce qu'il
    /// ne doit plus bouger. Recalcule un an plus tard, il aurait fondu — les
    /// cartes ont continue de palir sans que personne les revise.
    @MainActor
    @discardableResult
    static func close(_ season: Season, report: SeasonReport.Report, context: ModelContext) -> Season {
        season.closedAt = .now
        season.finalAcquiredPercent = report.acquired
        season.finalPagesCount = report.pages
        season.finalWritingHours = report.writingHours

        // Les cahiers s'archivent : ils restent lisibles et cherchables, mais
        // ne s'ouvrent plus sur la planche du semestre en cours.
        //
        // On les prend dans le contexte, pas dans `season.courses` : rien
        // n'attache un cahier a une saison au moment ou il est cree, donc la
        // relation est vide et n'archiverait rien. On la renseigne ici, pour
        // que la saison archivee sache ce qu'elle contenait.
        for course in courses(context) {
            course.archivedAt = .now
            course.season = season
        }

        let next = Season(name: SeasonReport.nextName(after: season.name), startsAt: .now)
        context.insert(next)
        try? context.save()
        return next
    }
}
