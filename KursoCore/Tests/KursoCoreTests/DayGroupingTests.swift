import Testing
import Foundation
@testable import KursoCore

@Suite("Regroupement des pages par jour")
struct DayGroupingTests {

    struct Item: Equatable { let name: String; let at: Date }

    var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }

    func date(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f.date(from: iso)!
    }

    @Test("Une liste vide rend zero jour")
    func empty() {
        let days = DayGrouping.byDay([Item](), calendar: calendar) { $0.at }
        #expect(days.isEmpty)
    }

    @Test("Les pages du meme jour sont regroupees")
    func sameDayGroups() {
        let items = [
            Item(name: "matin", at: date("2026-09-07T09:00:00Z")),
            Item(name: "soir",  at: date("2026-09-07T20:00:00Z")),
        ]
        let days = DayGrouping.byDay(items, calendar: calendar) { $0.at }
        #expect(days.count == 1)
        #expect(days[0].items.count == 2)
    }

    @Test("Les jours vont du plus recent au plus ancien")
    func daysDescending() {
        let items = [
            Item(name: "vieux",  at: date("2026-09-01T10:00:00Z")),
            Item(name: "recent", at: date("2026-09-07T10:00:00Z")),
            Item(name: "milieu", at: date("2026-09-04T10:00:00Z")),
        ]
        let days = DayGrouping.byDay(items, calendar: calendar) { $0.at }
        #expect(days.map(\.items.first?.name) == ["recent", "milieu", "vieux"])
    }

    @Test("Dans un jour, la derniere page est en tete")
    func itemsDescendingWithinDay() {
        let items = [
            Item(name: "8h",  at: date("2026-09-07T08:00:00Z")),
            Item(name: "14h", at: date("2026-09-07T14:00:00Z")),
            Item(name: "11h", at: date("2026-09-07T11:00:00Z")),
        ]
        let days = DayGrouping.byDay(items, calendar: calendar) { $0.at }
        #expect(days[0].items.map(\.name) == ["14h", "11h", "8h"])
    }

    @Test("Deux pages a une minute d'ecart mais de part et d'autre de minuit font deux jours")
    func midnightBoundary() {
        let items = [
            Item(name: "avant", at: date("2026-09-07T23:59:00Z")),
            Item(name: "apres", at: date("2026-09-08T00:01:00Z")),
        ]
        let days = DayGrouping.byDay(items, calendar: calendar) { $0.at }
        #expect(days.count == 2)
        #expect(days[0].items.map(\.name) == ["apres"])
    }

    @Test("Le debut de journee est bien minuit")
    func dayStartIsMidnight() {
        let items = [Item(name: "x", at: date("2026-09-07T15:30:00Z"))]
        let days = DayGrouping.byDay(items, calendar: calendar) { $0.at }
        #expect(days[0].start == date("2026-09-07T00:00:00Z"))
    }
}
