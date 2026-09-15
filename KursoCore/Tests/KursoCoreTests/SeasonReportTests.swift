import Foundation
import Testing
@testable import KursoCore

@Suite("Relevé de saison")
struct SeasonReportTests {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    /// Une carte fraiche : due dans le futur.
    private func fresh(_ interval: Int = 30) -> Freshness.CardState {
        .init(dueAt: now.addingTimeInterval(86_400), interval: interval)
    }

    /// Une carte en retard de `days` jours.
    private func late(_ days: Double, interval: Int = 10) -> Freshness.CardState {
        .init(dueAt: now.addingTimeInterval(-days * 86_400), interval: interval)
    }

    @Test("Un semestre vide ne ment pas")
    func empty() {
        let report = SeasonReport.make(pages: [], cardsReviewed: 0, longestStreak: 0, level: 1, now: now)
        #expect(report.pages == 0)
        #expect(report.acquiredPercent == 0)
        #expect(report.mineChanges == 0)
        #expect(report.states.isEmpty)
    }

    @Test("Les heures d'ecriture sont arrondies au dixieme")
    func hours() {
        let pages = [SeasonReport.PageInput(writingSeconds: 5_400, cards: [fresh()]),
                     SeasonReport.PageInput(writingSeconds: 1_800, cards: [fresh()])]
        let report = SeasonReport.make(pages: pages, cardsReviewed: 0, longestStreak: 0, level: 1, now: now)
        #expect(report.writingHours == 2.0)
    }

    @Test("Un brouillon compte en pages, pas dans la carte")
    func draftsCountAsPages() {
        // Une page sans carte ne doit pas faire baisser le pourcentage :
        // le §3 dit qu'on ne reproche pas de ne pas avoir fini.
        let pages = [SeasonReport.PageInput(writingSeconds: 600, cards: [fresh()]),
                     SeasonReport.PageInput(writingSeconds: 600, cards: [])]
        let report = SeasonReport.make(pages: pages, cardsReviewed: 0, longestStreak: 0, level: 1, now: now)
        #expect(report.pages == 2)
        #expect(report.acquiredPercent == 100)
        #expect(report.count(.draft) == 1)
    }

    @Test("Les pastilles suivent l'ordre des pages")
    func statesFollowPages() {
        let pages = [SeasonReport.PageInput(writingSeconds: 0, cards: [fresh()]),
                     SeasonReport.PageInput(writingSeconds: 0, cards: [late(40)]),
                     SeasonReport.PageInput(writingSeconds: 0, cards: [])]
        let report = SeasonReport.make(pages: pages, cardsReviewed: 0, longestStreak: 0, level: 1, now: now)
        #expect(report.states.count == 3)
        #expect(report.states[0] == .acquired)
        #expect(report.states[2] == .draft)
    }

    @Test("Une carte a demi palie ne compte pas pour rien")
    func partialCounts() {
        // Deux noeuds : un intact, un a moitie efface. Le releve doit tomber
        // entre les deux, pas a 50 % de noeuds verts.
        let pages = [SeasonReport.PageInput(writingSeconds: 0, cards: [fresh()]),
                     SeasonReport.PageInput(writingSeconds: 0, cards: [late(10, interval: 10)])]
        let report = SeasonReport.make(pages: pages, cardsReviewed: 0, longestStreak: 0, level: 1, now: now)
        #expect(report.acquiredPercent > 50)
        #expect(report.acquiredPercent < 100)
    }

    @Test("Une fiche or demande le sans-faute")
    func goldNeedsPerfection() {
        let mature = Freshness.CardState(dueAt: now.addingTimeInterval(86_400), interval: 30)
        let clean = SeasonReport.PageInput(writingSeconds: 0, cards: [mature], lapses: 0)
        let scarred = SeasonReport.PageInput(writingSeconds: 0, cards: [mature], lapses: 2)
        let report = SeasonReport.make(pages: [clean, scarred], cardsReviewed: 0, longestStreak: 0, level: 1, now: now)
        #expect(report.goldFiches == 1)
        #expect(report.totalFiches == 2)
    }

    @Test("Un taille-crayon par niveau franchi")
    func mineChanges() {
        #expect(SeasonReport.make(pages: [], cardsReviewed: 0, longestStreak: 0, level: 8, now: now).mineChanges == 7)
    }

    @Test("Les compteurs negatifs sont ramenes a zero")
    func noNegatives() {
        let report = SeasonReport.make(pages: [], cardsReviewed: -5, longestStreak: -2, level: 0, now: now)
        #expect(report.cardsReviewed == 0)
        #expect(report.longestStreak == 0)
        #expect(report.mineChanges == 0)
    }

    @Test("Le partage ne sort que des chiffres")
    func shareText() {
        let pages = [SeasonReport.PageInput(writingSeconds: 3_600, cards: [fresh()])]
        let report = SeasonReport.make(pages: pages, cardsReviewed: 40, longestStreak: 9, level: 3, now: now)
        let text = SeasonReport.shareText(report, seasonName: "Semestre 5")
        #expect(text.contains("Semestre 5"))
        #expect(text.contains("Carte acquise : 100 %"))
        #expect(text.contains("Cartes revues : 40"))
        #expect(text.contains("Fiches or : 1 sur 1"))
    }

    @Test("Le semestre suivant s'incremente tout seul")
    func nextName() {
        #expect(SeasonReport.nextName(after: "Semestre 5") == "Semestre 6")
        #expect(SeasonReport.nextName(after: "Semestre 9") == "Semestre 10")
    }

    @Test("Seul le dernier nombre bouge")
    func onlyLastNumber() {
        // « 2024-1 » doit passer a « 2024-2 », pas a « 2025-1 ».
        #expect(SeasonReport.nextName(after: "Semestre 2024-1") == "Semestre 2024-2")
    }

    @Test("Un nom sans chiffre reste lisible")
    func noNumber() {
        #expect(SeasonReport.nextName(after: "Prépa") == "Prépa (suite)")
        #expect(SeasonReport.nextName(after: "   ") == "Nouveau semestre")
    }

    @Test("La phrase d'ouverture reprend le pourcentage")
    func headline() {
        let pages = [SeasonReport.PageInput(writingSeconds: 0, cards: [fresh()])]
        let report = SeasonReport.make(pages: pages, cardsReviewed: 0, longestStreak: 0, level: 1, now: now)
        #expect(SeasonReport.headline(report) == "Tu as fini le semestre avec 100 % de ta carte acquise.")
    }
}
