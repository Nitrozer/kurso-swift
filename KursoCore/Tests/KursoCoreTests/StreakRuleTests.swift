import Testing
import Foundation
@testable import KursoCore

@Suite("Série — §9")
struct StreakRuleTests {
    private let cal = Calendar(identifier: .gregorian)
    private func day(_ offset: Int) -> Date {
        Calendar(identifier: .gregorian).date(byAdding: .day, value: offset, to: Date(timeIntervalSince1970: 1_700_000_000))!
    }

    @Test("La premiere session ouvre la serie")
    func firstSession() {
        let r = StreakRule.sessionFinished(.init(), on: day(0), calendar: cal)
        #expect(r.streak == 1)
        #expect(r.record == 1)
    }

    @Test("Un jour de plus, un point de plus")
    func consecutiveDays() {
        var s = StreakRule.State(streak: 3, record: 5, lastDay: day(0), freezes: 0)
        s = StreakRule.sessionFinished(s, on: day(1), calendar: cal)
        #expect(s.streak == 4)
        #expect(s.record == 5)
    }

    @Test("Deux sessions le meme jour ne comptent qu'une fois")
    func sameDayIsIdempotent() {
        let start = StreakRule.State(streak: 4, record: 4, lastDay: day(2), freezes: 0)
        let once = StreakRule.sessionFinished(start, on: day(2), calendar: cal)
        let twice = StreakRule.sessionFinished(once, on: day(2), calendar: cal)
        #expect(once.streak == 4)
        #expect(twice.streak == 4)
    }

    @Test("Un gel rattrape une journee manquee")
    func freezeCoversOneDay() {
        var s = StreakRule.State(streak: 7, record: 7, lastDay: day(0), freezes: 2)
        s = StreakRule.sessionFinished(s, on: day(2), calendar: cal)
        #expect(s.streak == 8)
        #expect(s.freezes == 1)
    }

    @Test("Sans gel, la serie repart a un")
    func withoutFreezeItResets() {
        var s = StreakRule.State(streak: 7, record: 7, lastDay: day(0), freezes: 0)
        s = StreakRule.sessionFinished(s, on: day(2), calendar: cal)
        #expect(s.streak == 1)
        #expect(s.record == 7, "le record ne descend jamais")
    }

    @Test("Deux jours manques, un gel ne suffit pas")
    func freezeCoversOnlyOneDay() {
        var s = StreakRule.State(streak: 9, record: 9, lastDay: day(0), freezes: 2)
        s = StreakRule.sessionFinished(s, on: day(3), calendar: cal)
        #expect(s.streak == 1)
        #expect(s.freezes == 2, "un gel qui ne sert a rien n'est pas consomme")
    }

    @Test("Le record suit la serie quand elle le depasse")
    func recordFollows() {
        var s = StreakRule.State(streak: 9, record: 9, lastDay: day(0), freezes: 0)
        s = StreakRule.sessionFinished(s, on: day(1), calendar: cal)
        #expect(s.record == 10)
    }
}
