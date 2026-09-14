import Foundation
import SwiftData
import KursoCore
import KursoModels

/// Acces a l'activite du jour.
enum DailyActivityStore {

    @MainActor
    static func today(context: ModelContext, calendar: Calendar = .current) -> DailyActivity {
        let day = calendar.startOfDay(for: .now)
        let descriptor = FetchDescriptor<DailyActivity>(predicate: #Predicate { $0.day == day })
        if let existing = try? context.fetch(descriptor).first { return existing }
        let created = DailyActivity(day: day)
        context.insert(created)
        try? context.save()
        return created
    }

    @MainActor
    static func record(_ kind: DailyProgress.QuestKind, amount: Int = 1, context: ModelContext) {
        let activity = today(context: context)
        switch kind {
        case .writePage:   activity.pagesWritten += amount
        case .reviewCards: activity.cardsReviewed += amount
        case .captureCard: activity.cardsCaptured += amount
        }
        try? context.save()
    }

    /// L'XP du jour, affiche au passage de niveau.
    @MainActor
    static func record(xp: Int, context: ModelContext) {
        guard xp != 0 else { return }
        today(context: context).xpEarned += xp
        try? context.save()
    }

    static func progress(_ kind: DailyProgress.QuestKind, in activity: DailyActivity) -> Int {
        switch kind {
        case .writePage:   activity.pagesWritten
        case .reviewCards: activity.cardsReviewed
        case .captureCard: activity.cardsCaptured
        }
    }
}
