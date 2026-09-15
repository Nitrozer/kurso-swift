import Foundation
import Testing
@testable import KursoCore

@Suite("Rappels — §12")
struct RemindersTests {

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Paris")!
        return cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 9) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    @Test("Un partiel donne un rappel a J-14 et un la veille")
    func examReminders() {
        // Jeudi 15 janvier 2026.
        let exam = Reminders.Exam(id: UUID(), date: date(2026, 1, 15),
                                  courseName: "Automatique", fragilePages: 4)
        let plan = Reminders.plan(exams: [exam], now: date(2025, 12, 1), calendar: calendar)
        #expect(plan.count == 2)
        #expect(plan.first?.body.contains("4 pages") == true)
        #expect(plan.last?.title.contains("c'est demain") == true)
    }

    @Test("Un rappel deja passe n'est pas pose")
    func noPastReminders() {
        let exam = Reminders.Exam(id: UUID(), date: date(2026, 1, 15),
                                  courseName: "Automatique", fragilePages: 0)
        // On est la veille : seul le rappel de demain reste.
        let plan = Reminders.plan(exams: [exam], now: date(2026, 1, 14, 8), calendar: calendar)
        #expect(plan.count == 1)
    }

    @Test("Jamais plus de deux par jour")
    func twoPerDayMax() {
        let due = date(2026, 3, 5)
        let tasks = (0..<5).map { Reminders.Task(id: UUID(), dueAt: due, title: "Devoir \($0)") }
        let plan = Reminders.plan(tasks: tasks, now: date(2026, 1, 1), calendar: calendar)
        #expect(plan.count == Reminders.maxPerDay)
    }

    @Test("Rien le week-end sans echeance")
    func silentWeekend() {
        // Echeance mercredi : le rappel de la veille tombe un mardi, donc pose.
        let midweek = Reminders.Task(id: UUID(), dueAt: date(2026, 1, 14), title: "TD")
        #expect(Reminders.plan(tasks: [midweek], now: date(2026, 1, 1), calendar: calendar).count == 1)

        // Echeance mardi 20 : la veille est lundi, pose aussi. On verifie
        // plutot un rappel qui tomberait un samedi pour une echeance de mardi.
        let far = Reminders.Task(id: UUID(), dueAt: date(2026, 1, 20), title: "DM")
        let plan = Reminders.plan(tasks: [far], now: date(2026, 1, 1), calendar: calendar)
        #expect(plan.allSatisfy { !Reminders.isWeekend($0.date, calendar: calendar) })
    }

    @Test("Un devoir a rendre lundi se rappelle bien le dimanche")
    func weekendWhenDeadlineIsMonday() {
        // Lundi 19 janvier 2026 : la veille est un dimanche, et l'echeance
        // le lendemain justifie le rappel.
        let monday = Reminders.Task(id: UUID(), dueAt: date(2026, 1, 19), title: "Rapport")
        let plan = Reminders.plan(tasks: [monday], now: date(2026, 1, 1), calendar: calendar)
        #expect(plan.count == 1)
        #expect(Reminders.isWeekend(plan[0].date, calendar: calendar))
    }

    @Test("Les identifiants sont stables")
    func stableIdentifiers() {
        // Replanifier ne doit pas empiler deux fois le meme rappel.
        let exam = Reminders.Exam(id: UUID(), date: date(2026, 1, 15),
                                  courseName: "Automatique", fragilePages: 1)
        let first = Reminders.plan(exams: [exam], now: date(2025, 12, 1), calendar: calendar)
        let again = Reminders.plan(exams: [exam], now: date(2025, 12, 1), calendar: calendar)
        #expect(first.map(\.id) == again.map(\.id))
    }

    @Test("Le rappel tombe le soir, pas au reveil")
    func eveningHour() {
        let exam = Reminders.Exam(id: UUID(), date: date(2026, 1, 15),
                                  courseName: "Automatique", fragilePages: 0)
        let plan = Reminders.plan(exams: [exam], now: date(2025, 12, 1), calendar: calendar)
        #expect(plan.allSatisfy { calendar.component(.hour, from: $0.date) == Reminders.hour })
    }
}
