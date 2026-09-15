import Foundation
import SwiftData
import UserNotifications
import KursoCore
import KursoModels

/// Pose les rappels decides par `Reminders`.
///
/// L'autorisation n'est demandee qu'au moment ou il y a vraiment quelque chose
/// a rappeler : demander au premier lancement, avant le moindre cours, c'est
/// deja une notification de trop.
enum ReminderScheduler {

    /// Prefixe des rappels poses par Kurso, pour ne retirer que les siens.
    static let prefix = "kurso."

    /// Le plan se calcule sur l'acteur principal, la pose se fait a cote.
    ///
    /// `UNUserNotificationCenter` n'est pas `Sendable` : le faire traverser
    /// une frontiere d'isolation est refuse par Swift 6. Seul le plan voyage,
    /// et lui l'est.
    @MainActor
    static func refresh(_ context: ModelContext, now: Date = .now) async {
        await apply(plan(context, now: now))
    }

    nonisolated static func apply(_ plan: [Reminders.Reminder]) async {
        let center = UNUserNotificationCenter.current()

        // On retire d'abord : replanifier doit remplacer, pas empiler.
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(
            withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
        )

        guard !plan.isEmpty, await authorised() else { return }

        for reminder in plan {
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default

            let parts = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: reminder.date)
            let request = UNNotificationRequest(
                identifier: prefix + reminder.id,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            )
            try? await center.add(request)
        }
    }

    @MainActor
    static func plan(_ context: ModelContext, now: Date = .now) -> [Reminders.Reminder] {
        var exams: [Reminders.Exam] = []
        if let season = SeasonStore.current(context), let date = season.examDate, date > now {
            let pages = (try? context.fetch(FetchDescriptor<Page>())) ?? []
            let fragile = pages
                .filter { $0.course?.archivedAt == nil }
                .filter { page in
                    let cards = page.cards ?? []
                    guard !cards.isEmpty else { return false }
                    return Freshness.state(
                        cards: cards.map { Freshness.CardState(dueAt: $0.dueAt, interval: $0.interval) },
                        now: now
                    ) == .endangered
                }
                .count
            exams.append(.init(id: season.id, date: date,
                               courseName: season.name, fragilePages: fragile))
        }

        let tasks = ((try? context.fetch(FetchDescriptor<Assignment>())) ?? [])
            .filter { !$0.isDone }
            .compactMap { task -> Reminders.Task? in
                guard let due = task.dueAt, due > now else { return nil }
                return .init(id: task.id, dueAt: due, title: task.title)
            }

        return Reminders.plan(exams: exams, tasks: tasks, now: now)
    }

    /// Demande l'autorisation une seule fois, et seulement si on a de quoi
    /// rappeler quelque chose.
    nonisolated private static func authorised() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        default:
            return false
        }
    }
}
