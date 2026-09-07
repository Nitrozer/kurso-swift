import Testing
import Foundation
@testable import KursoCore

@Suite("L'encre qui palit — §3")
struct FreshnessTests {

    let now = Date(timeIntervalSince1970: 1_800_000_000)
    func daysAgo(_ d: Double) -> Date { now.addingTimeInterval(-d * 86_400) }
    func inDays(_ d: Double) -> Date { now.addingTimeInterval(d * 86_400) }

    @Test("Une page sans carte est un brouillon et ne palit pas")
    func draftNeverFades() {
        // On ne reproche pas de ne pas avoir fini.
        #expect(Freshness.compute(cards: [], now: now) == 1.0)
        #expect(Freshness.state(cards: [], now: now) == .draft)
    }

    @Test("Une carte pas encore due laisse la page intacte")
    func notYetDue() {
        let card = Freshness.CardState(dueAt: inDays(5), interval: 10)
        #expect(Freshness.compute(cards: [card], now: now) == 1.0)
        #expect(Freshness.state(cards: [card], now: now) == .acquired)
    }

    @Test("Le retard fait palir proportionnellement a l'intervalle")
    func fadesWithLateness() {
        // 5 jours de retard sur un intervalle de 10 : 1 - 5/20 = 0,75.
        let card = Freshness.CardState(dueAt: daysAgo(5), interval: 10)
        #expect(abs(Freshness.compute(cards: [card], now: now) - 0.75) < 0.001)
    }

    @Test("La fraicheur ne descend jamais sous zero")
    func neverNegative() {
        let card = Freshness.CardState(dueAt: daysAgo(500), interval: 1)
        #expect(Freshness.compute(cards: [card], now: now) == 0)
    }

    @Test("La fraicheur est la moyenne des cartes")
    func averagesCards() {
        let fresh = Freshness.CardState(dueAt: inDays(5), interval: 10)   // 1,0
        let late  = Freshness.CardState(dueAt: daysAgo(10), interval: 10) // 0,5
        #expect(abs(Freshness.compute(cards: [fresh, late], now: now) - 0.75) < 0.001)
    }

    @Test("Les trois etats suivent les seuils du tableau")
    func statesFollowThresholds() {
        func state(daysLate: Double, interval: Int) -> Freshness.State {
            Freshness.state(cards: [.init(dueAt: daysAgo(daysLate), interval: interval)], now: now)
        }
        #expect(state(daysLate: 1, interval: 10) == .acquired)    // 0,95
        #expect(state(daysLate: 10, interval: 10) == .toReview)   // 0,50
        #expect(state(daysLate: 18, interval: 10) == .endangered) // 0,10
    }

    @Test("Un intervalle nul ne divise pas par zero")
    func zeroIntervalIsSafe() {
        let card = Freshness.CardState(dueAt: daysAgo(1), interval: 0)
        #expect(Freshness.compute(cards: [card], now: now) == 0.5)
    }
}
