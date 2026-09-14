import Foundation
import SwiftData

/// L'activite d'une journee, pour l'avancement des quetes (§9).
///
/// Une ligne par jour plutot qu'un compteur remis a zero : on peut ainsi
/// relire la semaine passee, et une remise a zero ratee ne fait pas disparaitre
/// une journee de travail.
@Model public final class DailyActivity {
    public var id: UUID = UUID()
    /// Minuit du jour concerne.
    public var day: Date = Date()
    public var pagesWritten: Int = 0
    public var cardsReviewed: Int = 0
    public var cardsCaptured: Int = 0
    /// XP gagnes dans la journee, affiches au passage de niveau.
    public var xpEarned: Int = 0
    /// Quetes deja encaissees, pour ne pas rendre l'XP deux fois.
    public var claimedQuests: [String] = []

    public init(day: Date = Date()) { self.day = day }
}
