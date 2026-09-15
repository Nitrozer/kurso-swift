import Testing
import Foundation
@testable import KursoCore

@Suite("Ligue — §9")
struct LeagueRulesTests {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        calendar.firstWeekday = 2
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private func standings(_ pairs: [(String, Int)]) -> [LeagueRules.Standing] {
        pairs.map { LeagueRules.Standing(id: $0.0, name: $0.0, weeklyXP: $0.1) }
    }

    @Test("Douze places, pas treize")
    func capacity() {
        let crowd = standings((1...20).map { ("ami \($0)", $0 * 10) })
        #expect(LeagueRules.table(crowd).count == LeagueRules.capacity)
        #expect(LeagueRules.capacity == 12)
    }

    @Test("Le plus d'XP en haut")
    func ordering() {
        let table = LeagueRules.table(standings([("Ana", 120), ("Bob", 400), ("Cid", 250)]))
        #expect(table.map(\.name) == ["Bob", "Cid", "Ana"])
    }

    @Test("A egalite, l'ordre ne change pas d'une ouverture a l'autre")
    func stableTies() {
        let once = LeagueRules.table(standings([("Zoe", 100), ("Ana", 100), ("Bob", 100)]))
        let twice = LeagueRules.table(standings([("Bob", 100), ("Zoe", 100), ("Ana", 100)]))
        #expect(once.map(\.name) == twice.map(\.name))
        #expect(once.map(\.name) == ["Ana", "Bob", "Zoe"])
    }

    @Test("Le rang se lit a partir de un")
    func ranking() {
        let table = standings([("Ana", 120), ("Bob", 400), ("Cid", 250)])
        #expect(LeagueRules.rank(of: "Bob", in: table) == 1)
        #expect(LeagueRules.rank(of: "Ana", in: table) == 3)
        #expect(LeagueRules.rank(of: "absent", in: table) == nil)
    }

    @Test("Les trois premiers montent, le quatrieme non")
    func promotion() {
        #expect(LeagueRules.isPromoted(rank: 1))
        #expect(LeagueRules.isPromoted(rank: 3))
        #expect(!LeagueRules.isPromoted(rank: 4))
        #expect(LeagueRules.promotedCount == 3)
    }

    @Test("Personne ne descend, jamais")
    func nobodyEverFallsBack() {
        // Dernier de la ligue, une semaine a zero : on reste. Le cas
        // « descendre » n'existe pas dans le type, et c'est voulu.
        #expect(LeagueRules.outcome(grade: .b4, rank: 12) == .stays)
        #expect(LeagueRules.outcome(grade: .hb, rank: 9) == .stays)
    }

    @Test("Les grades suivent les duretes de mine")
    func grades() {
        #expect(LeagueRules.Grade.allCases.map(\.label) == ["HB", "2B", "4B", "6B"])
        #expect(LeagueRules.Grade.hb.next == .b2)
        #expect(LeagueRules.Grade.b4.next == .b6)
        #expect(LeagueRules.Grade.b6.next == nil)
    }

    @Test("Premier en 6B : on reste au sommet, ce n'est pas un echec")
    func topOfTheMines() {
        #expect(LeagueRules.outcome(grade: .hb, rank: 2) == .promoted(.b2))
        #expect(LeagueRules.outcome(grade: .b6, rank: 1) == .atTop)
    }

    @Test("La semaine ouvre le lundi 04:00")
    func weekStart() {
        let wednesday = date(2026, 9, 16, 15)
        #expect(LeagueRules.weekStart(for: wednesday, calendar: calendar) == date(2026, 9, 14, 4))
    }

    @Test("Reviser le lundi a 01:00 finit la semaine commencee")
    func mondayNightBelongsToLastWeek() {
        let mondayNight = date(2026, 9, 14, 1)
        #expect(LeagueRules.weekStart(for: mondayNight, calendar: calendar) == date(2026, 9, 7, 4))
    }

    @Test("La remise a zero n'a lieu qu'une fois par semaine")
    func reset() {
        let openedAt = date(2026, 9, 14, 4)
        #expect(!LeagueRules.needsReset(weekStartedAt: openedAt, now: date(2026, 9, 18, 9), calendar: calendar))
        #expect(LeagueRules.needsReset(weekStartedAt: openedAt, now: date(2026, 9, 21, 9), calendar: calendar))
    }

    @Test("La ligue ferme le dimanche 20:00")
    func closing() {
        #expect(LeagueRules.closes(after: date(2026, 9, 16, 15), calendar: calendar) == date(2026, 9, 20, 20))
        // Dimanche 20:00 pile est deja passe : la fermeture suivante est dans huit jours.
        #expect(LeagueRules.closes(after: date(2026, 9, 20, 20), calendar: calendar) == date(2026, 9, 27, 20))
        #expect(LeagueRules.closes(after: date(2026, 9, 20, 19), calendar: calendar) == date(2026, 9, 20, 20))
    }

    @Test("Ce qu'on lit sous le tableau n'a rien d'une menace")
    func summary() {
        #expect(LeagueRules.summary(rank: nil, grade: .hb, count: 0).contains("Ajoute des amis"))
        #expect(LeagueRules.summary(rank: 1, grade: .hb, count: 5).contains("2B"))
        #expect(LeagueRules.summary(rank: 1, grade: .b6, count: 5).contains("sommet"))
        #expect(LeagueRules.summary(rank: 4, grade: .hb, count: 8) == "Une place te sépare des trois qui montent.")
        #expect(LeagueRules.summary(rank: 6, grade: .hb, count: 8).hasPrefix("3 places"))
        // Seul dans sa ligue, aucun classement n'a de sens.
        #expect(LeagueRules.summary(rank: 1, grade: .hb, count: 1).contains("seul"))
    }
}
