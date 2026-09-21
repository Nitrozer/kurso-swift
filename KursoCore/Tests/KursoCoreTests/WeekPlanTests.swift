import Testing
import Foundation
@testable import KursoCore

@Suite("La semaine")
struct WeekPlanTests {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        // Regle a l'americaine EXPRES : la semaine scolaire doit commencer le
        // lundi quoi qu'il arrive.
        calendar.firstWeekday = 1
        return calendar
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    @Test("La semaine commence le lundi, quelle que soit la langue de l'appareil")
    func mondayFirst() {
        // Mercredi 23 septembre 2026.
        let days = WeekPlan.days(containing: date(2026, 9, 23, 15), calendar: calendar)
        #expect(days.count == 7)
        #expect(days.first == date(2026, 9, 21))
        #expect(days.last == date(2026, 9, 27))
    }

    @Test("Un lundi et un dimanche tombent dans la bonne semaine")
    func edges() {
        #expect(WeekPlan.days(containing: date(2026, 9, 21, 7), calendar: calendar).first == date(2026, 9, 21))
        // Le dimanche ferme la semaine, il ne l'ouvre pas.
        #expect(WeekPlan.days(containing: date(2026, 9, 27, 23), calendar: calendar).first == date(2026, 9, 21))
    }

    @Test("On n'affiche que les heures occupées")
    func onlyBusyHours() {
        // Minuit a minuit consacrerait les trois quarts de l'ecran a des
        // heures ou personne n'a cours.
        let slots = [(start: date(2026, 9, 21, 10), end: date(2026, 9, 21, 12)),
                     (start: date(2026, 9, 23, 14), end: date(2026, 9, 23, 17, 30))]
        #expect(WeekPlan.hours(for: slots, calendar: calendar) == 10...18)
    }

    @Test("Une semaine vide garde une grille lisible")
    func emptyWeek() {
        #expect(WeekPlan.hours(for: [], calendar: calendar) == 8...18)
    }

    @Test("Un seul cours ne donne pas une bande")
    func minimumSpan() {
        let slots = [(start: date(2026, 9, 21, 10), end: date(2026, 9, 21, 11))]
        let hours = WeekPlan.hours(for: slots, calendar: calendar)
        #expect(hours.upperBound - hours.lowerBound >= 4)
    }

    @Test("Un créneau se place à sa place")
    func placement() {
        let slot = (start: date(2026, 9, 21, 10), end: date(2026, 9, 21, 12))
        let place = WeekPlan.placement(slot, in: 8...18, calendar: calendar)
        #expect(abs(place.y - 0.2) < 0.001)
        #expect(abs(place.height - 0.2) < 0.001)
    }

    @Test("Un créneau très court reste attrapable")
    func tinySlotStaysUsable() {
        let slot = (start: date(2026, 9, 21, 10), end: date(2026, 9, 21, 10, 10))
        #expect(WeekPlan.placement(slot, in: 8...18, calendar: calendar).height >= 0.02)
    }

    @Test("Le titre nomme le mois, et les deux quand la semaine les enjambe")
    func titles() {
        let septembre = WeekPlan.days(containing: date(2026, 9, 23), calendar: calendar)
        #expect(WeekPlan.title(septembre, calendar: calendar) == "21 – 27 septembre")
        let cheval = WeekPlan.days(containing: date(2026, 9, 30), calendar: calendar)
        #expect(WeekPlan.title(cheval, calendar: calendar) == "28 septembre – 4 octobre")
    }

    @Test("Les jours s'abrègent en français")
    func dayNames() {
        #expect(WeekPlan.shortName(date(2026, 9, 21), calendar: calendar) == "lun")
        #expect(WeekPlan.shortName(date(2026, 9, 27), calendar: calendar) == "dim")
    }
}
