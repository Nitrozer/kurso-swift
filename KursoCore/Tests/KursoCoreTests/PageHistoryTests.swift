import Testing
import Foundation
@testable import KursoCore

@Suite("Historique d'une page")
struct PageHistoryTests {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        calendar.firstWeekday = 2
        return calendar
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    @Test("Un trace inchangé ne merite pas d'instantané")
    func unchangedIsNotKept() {
        let now = Date()
        #expect(!PageHistory.shouldKeep(last: nil, now: now, changed: false))
        #expect(PageHistory.shouldKeep(last: nil, now: now, changed: true))
    }

    @Test("Deux instantanés ne se suivent pas de trop près")
    func minimumGap() {
        // Sans ce delai, une heure d'ecriture en produirait des dizaines.
        let now = Date()
        #expect(!PageHistory.shouldKeep(last: now.addingTimeInterval(-60), now: now, changed: true))
        #expect(PageHistory.shouldKeep(last: now.addingTimeInterval(-1_800), now: now, changed: true))
        #expect(PageHistory.minimumGap == 20 * 60)
    }

    @Test("On sacrifie celui qui laisse le plus petit trou")
    func dropsTheLeastInformative() {
        // Trois instantanés colles et un isole : c'est dans le paquet qu'on
        // prend, pour garder l'histoire la plus etalee.
        let dates = [
            date(2026, 9, 1, 8),
            date(2026, 9, 21, 10),
            date(2026, 9, 21, 10, 5),
            date(2026, 9, 21, 10, 10),
            date(2026, 9, 21, 18),
            date(2026, 9, 22, 9),
            date(2026, 9, 22, 20),
        ]
        #expect(PageHistory.expendable(dates, limit: 6) == date(2026, 9, 21, 10, 5))
    }

    @Test("Ni le plus récent ni le plus ancien ne partent")
    func keepsBothEnds() {
        let dates = (0..<8).map { date(2026, 9, 21, 8 + $0) }
        let dropped = PageHistory.expendable(dates, limit: 6)
        #expect(dropped != dates.first)
        #expect(dropped != dates.last)
    }

    @Test("Sous la limite, on ne sacrifie rien")
    func nothingToDrop() {
        let dates = (0..<4).map { date(2026, 9, 21, 8 + $0) }
        #expect(PageHistory.expendable(dates, limit: 6) == nil)
        #expect(PageHistory.expendable([], limit: 6) == nil)
    }

    @Test("Au-delà de deux semaines, c'est la sauvegarde qui répond")
    func oldOnesExpire() {
        let now = date(2026, 9, 21, 12)
        let dates = [date(2026, 9, 20, 12), date(2026, 9, 1, 12)]
        #expect(PageHistory.expired(dates, now: now) == [date(2026, 9, 1, 12)])
    }

    @Test("Un instantané se nomme par une durée, pas par une date")
    func labels() {
        // « avant que j'efface » se cherche en duree, pas en horodatage.
        let now = date(2026, 9, 21, 20)
        #expect(PageHistory.label(now.addingTimeInterval(-30), now: now, calendar: calendar) == "à l'instant")
        #expect(PageHistory.label(now.addingTimeInterval(-1_800), now: now, calendar: calendar) == "il y a 30 min")
        #expect(PageHistory.label(date(2026, 9, 21, 17), now: now, calendar: calendar) == "il y a 3 h")
        #expect(PageHistory.label(date(2026, 9, 20, 18, 42), now: now, calendar: calendar).hasPrefix("hier"))
        #expect(PageHistory.label(date(2026, 9, 17, 9), now: now, calendar: calendar).hasPrefix("jeudi"))
    }
}
