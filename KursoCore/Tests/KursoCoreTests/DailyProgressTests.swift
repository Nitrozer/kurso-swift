import Testing
import Foundation
@testable import KursoCore

@Suite("Série et quêtes — §9")
struct DailyProgressTests {

    var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }
    let day0 = Date(timeIntervalSince1970: 1_800_000_000)
    func day(_ offset: Int) -> Date { day0.addingTimeInterval(Double(offset) * 86_400) }

    @Test("La première session ouvre la série à un")
    func firstSession() {
        #expect(DailyProgress.streak(current: 0, lastSessionDay: nil, today: day(0), calendar: calendar) == 1)
    }

    @Test("Un jour consécutif allonge la série")
    func consecutiveDay() {
        #expect(DailyProgress.streak(current: 5, lastSessionDay: day(0), today: day(1), calendar: calendar) == 6)
    }

    @Test("Une seconde session le même jour n'allonge rien")
    func sameDayDoesNotCount() {
        // La série compte les jours, pas les sessions.
        let later = day(0).addingTimeInterval(6 * 3600)
        #expect(DailyProgress.streak(current: 5, lastSessionDay: day(0), today: later, calendar: calendar) == 5)
    }

    @Test("Un jour manqué remet la série à un")
    func missedDayResets() {
        #expect(DailyProgress.streak(current: 12, lastSessionDay: day(0), today: day(2), calendar: calendar) == 1)
    }

    @Test("Un gel ne sauve qu'un trou d'une seule journée")
    func freezeCoversOneDayOnly() {
        // Geler une semaine d'absence viderait la série de son sens.
        #expect(DailyProgress.canFreeze(gapInDays: 2, freezesRemaining: 1))
        #expect(DailyProgress.canFreeze(gapInDays: 3, freezesRemaining: 2) == false)
        #expect(DailyProgress.canFreeze(gapInDays: 2, freezesRemaining: 0) == false)
    }

    @Test("La journée porte trois quêtes, et toujours les mêmes")
    func threeStableQuests() {
        #expect(DailyProgress.dailyQuests.count == 3)
        #expect(DailyProgress.dailyQuests.allSatisfy { (30...50).contains($0.xp) })
    }
}
