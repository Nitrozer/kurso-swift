import Foundation

/// Trouve le creneau en cours au moment ou une page s'ouvre (§6).
///
/// C'est ce qui range les pages sans aucune saisie : on ouvre son cahier
/// pendant le cours, la page se rattache seule a la bonne matiere.
public enum SlotMatcher {

    /// Tolerance autour du creneau : on arrive rarement pile a l'heure, et on
    /// finit souvent d'ecrire quelques minutes apres la fin.
    public static let tolerance: TimeInterval = 15 * 60

    public struct Slot: Equatable, Sendable {
        public let id: UUID
        public let start: Date
        public let end: Date

        public init(id: UUID, start: Date, end: Date) {
            self.id = id
            self.start = start
            self.end = end
        }
    }

    /// Rend le creneau en cours, ou `nil` si aucun ne correspond.
    ///
    /// Quand plusieurs creneaux se chevauchent — un TD qui deborde sur un CM,
    /// ou deux groupes importes ensemble — on retient celui dont le centre est
    /// le plus proche : c'est celui ou l'on est le plus probablement assis.
    public static func slotInProgress(
        at date: Date,
        among slots: [Slot],
        tolerance: TimeInterval = tolerance
    ) -> Slot? {
        let candidates = slots.filter { slot in
            date >= slot.start.addingTimeInterval(-tolerance)
                && date <= slot.end.addingTimeInterval(tolerance)
        }
        guard !candidates.isEmpty else { return nil }

        return candidates.min { lhs, rhs in
            distanceToCenter(date, lhs) < distanceToCenter(date, rhs)
        }
    }

    private static func distanceToCenter(_ date: Date, _ slot: Slot) -> TimeInterval {
        let center = slot.start.addingTimeInterval(slot.end.timeIntervalSince(slot.start) / 2)
        return abs(date.timeIntervalSince(center))
    }
}
