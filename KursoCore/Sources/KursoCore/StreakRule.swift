import Foundation

/// La serie : +1 par jour ou au moins une session est terminee (§9).
///
/// Un gel rattrape UNE journee manquee, et il n'y en a que deux en reserve.
/// Au-dela, la serie repart a 1 — sans punition ni message culpabilisant,
/// c'est le §12 qui l'exige.
public enum StreakRule {

    public struct State: Equatable, Sendable {
        public var streak: Int
        public var record: Int
        public var lastDay: Date?
        public var freezes: Int

        public init(streak: Int = 0, record: Int = 0,
                    lastDay: Date? = nil, freezes: Int = 0) {
            self.streak = streak
            self.record = record
            self.lastDay = lastDay
            self.freezes = freezes
        }
    }

    /// Applique une journee pendant laquelle une session a ete terminee.
    ///
    /// Idempotent : deux sessions le meme jour ne comptent qu'une fois, sinon
    /// la serie mesurerait l'assiduite d'un apres-midi et non celle d'un mois.
    public static func sessionFinished(_ state: State,
                                       on now: Date = .now,
                                       calendar: Calendar = .current) -> State {
        var next = state
        let today = calendar.startOfDay(for: now)

        guard let last = state.lastDay.map({ calendar.startOfDay(for: $0) }) else {
            next.streak = 1
            next.lastDay = today
            next.record = max(next.record, 1)
            return next
        }

        let gap = calendar.dateComponents([.day], from: last, to: today).day ?? 0
        switch gap {
        case ..<0, 0:
            return state          // deja compte aujourd'hui, ou horloge en arriere
        case 1:
            next.streak += 1
        case 2 where state.freezes > 0:
            // Un seul jour manque, et un gel pour le couvrir.
            next.freezes -= 1
            next.streak += 1
        default:
            next.streak = 1
        }

        next.lastDay = today
        next.record = max(next.record, next.streak)
        return next
    }
}
