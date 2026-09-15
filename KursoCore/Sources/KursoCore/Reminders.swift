import Foundation

/// Ce que Kurso a le droit de rappeler, et quand (§12).
///
/// Le §12 plafonne : **pas plus de deux notifications par jour, rien le
/// week-end sans echeance**. Ce module ne notifie rien — il decide, pour que
/// la regle soit testable au lieu d'etre une intention.
///
/// Une notification rare est lue ; une notification quotidienne est coupee.
public enum Reminders {

    public static let maxPerDay = 2

    public struct Reminder: Equatable, Sendable, Identifiable {
        /// Stable : replanifier ne doit pas empiler deux fois le meme rappel.
        public let id: String
        public let date: Date
        public let title: String
        public let body: String

        public init(id: String, date: Date, title: String, body: String) {
            self.id = id
            self.date = date
            self.title = title
            self.body = body
        }
    }

    public struct Exam: Equatable, Sendable {
        public let id: UUID
        public let date: Date
        public let courseName: String
        /// Pages laissees rouges : c'est ce qui rend le rappel utile.
        public let fragilePages: Int

        public init(id: UUID, date: Date, courseName: String, fragilePages: Int) {
            self.id = id
            self.date = date
            self.courseName = courseName
            self.fragilePages = fragilePages
        }
    }

    public struct Task: Equatable, Sendable {
        public let id: UUID
        public let dueAt: Date
        public let title: String

        public init(id: UUID, dueAt: Date, title: String) {
            self.id = id
            self.dueAt = dueAt
            self.title = title
        }
    }

    /// L'heure a laquelle un rappel tombe : le soir, pas au reveil.
    public static let hour = 18

    /// Les rappels a poser, tries par date.
    public static func plan(
        exams: [Exam] = [],
        tasks: [Task] = [],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [Reminder] {
        var candidates: [(Reminder, urgency: Int)] = []

        for exam in exams {
            // A J-14 : le mode partiel s'ouvre, et c'est le dernier moment ou
            // remonter des pages rouges sert encore a quelque chose.
            if let date = fire(daysBefore: ExamMode.window, of: exam.date, now: now, calendar: calendar) {
                candidates.append((
                    Reminder(id: "exam-\(exam.id)-\(ExamMode.window)", date: date,
                             title: "\(exam.courseName) dans \(ExamMode.window) jours",
                             body: body(forFragile: exam.fragilePages)),
                    urgency: 2
                ))
            }
            if let date = fire(daysBefore: 1, of: exam.date, now: now, calendar: calendar) {
                candidates.append((
                    Reminder(id: "exam-\(exam.id)-1", date: date,
                             title: "\(exam.courseName), c'est demain",
                             body: "Dernière session ce soir ?"),
                    urgency: 3
                ))
            }
        }

        for task in tasks {
            if let date = fire(daysBefore: 1, of: task.dueAt, now: now, calendar: calendar) {
                candidates.append((
                    Reminder(id: "task-\(task.id)", date: date,
                             title: "À rendre demain",
                             body: task.title),
                    urgency: 1
                ))
            }
        }

        return cap(candidates, calendar: calendar)
    }

    private static func body(forFragile pages: Int) -> String {
        guard pages > 0 else { return "Le mode révision s'ouvre." }
        return "\(pages) page\(pages > 1 ? "s sont" : " est") presque effacée\(pages > 1 ? "s" : "")."
    }

    /// La date de declenchement, ou nil si elle est deja passee.
    ///
    /// Le week-end est saute, **sauf** si l'echeance elle-meme y tombe : un
    /// devoir a rendre lundi matin se rappelle bien le dimanche soir.
    static func fire(
        daysBefore days: Int,
        of deadline: Date,
        now: Date,
        calendar: Calendar
    ) -> Date? {
        guard let day = calendar.date(byAdding: .day, value: -days, to: deadline),
              let fire = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day)
        else { return nil }
        guard fire > now else { return nil }

        if isWeekend(fire, calendar: calendar), !isWeekend(deadline, calendar: calendar),
           !calendar.isDate(deadline, inSameDayAs: calendar.date(byAdding: .day, value: 1, to: fire) ?? fire) {
            return nil
        }
        return fire
    }

    static func isWeekend(_ date: Date, calendar: Calendar) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 1 || weekday == 7
    }

    /// Deux par jour au maximum, les plus urgents d'abord.
    static func cap(_ candidates: [(Reminder, urgency: Int)], calendar: Calendar) -> [Reminder] {
        let sorted = candidates.sorted {
            $0.urgency == $1.urgency ? $0.0.date < $1.0.date : $0.urgency > $1.urgency
        }
        var perDay: [Date: Int] = [:]
        var kept: [Reminder] = []
        for (reminder, _) in sorted {
            let day = calendar.startOfDay(for: reminder.date)
            let count = perDay[day, default: 0]
            guard count < maxPerDay else { continue }
            perDay[day] = count + 1
            kept.append(reminder)
        }
        return kept.sorted { $0.date < $1.date }
    }
}
