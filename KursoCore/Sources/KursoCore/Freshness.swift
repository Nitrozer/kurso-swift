import Foundation

/// La fraicheur d'une page (§3) — la mecanique signature.
///
/// Jamais stockee : recalculee a l'affichage depuis l'etat des cartes. La
/// stocker obligerait a la mettre a jour partout a chaque revision, et une
/// valeur perimee ferait mentir la couleur.
public enum Freshness {

    /// Ce que la page doit dire d'elle-meme.
    ///
    /// Le mot accompagne toujours la couleur : aucune information ne repose sur
    /// la seule teinte, pour ceux qui ne la distinguent pas.
    public enum State: String, Sendable {
        case acquired  = "acquise"
        case toReview  = "à revoir"
        case endangered = "à sauver"
        case draft     = "brouillon"
    }

    /// Les donnees dont le calcul a besoin : le module ne connait pas `Card`.
    public struct CardState: Equatable, Sendable {
        public let dueAt: Date
        public let interval: Int

        public init(dueAt: Date, interval: Int) {
            self.dueAt = dueAt
            self.interval = interval
        }
    }

    /// Fraicheur de 0 a 1.
    ///
    /// Une page sans carte rend 1 : un brouillon ne palit pas. On ne reproche
    /// pas de ne pas avoir fini.
    public static func compute(cards: [CardState], now: Date = .now) -> Double {
        guard !cards.isEmpty else { return 1.0 }

        let scores = cards.map { card -> Double in
            let daysLate = now.timeIntervalSince(card.dueAt) / 86_400
            guard daysLate > 0 else { return 1.0 }
            return max(0, 1 - daysLate / Double(max(card.interval, 1) * 2))
        }
        return scores.reduce(0, +) / Double(scores.count)
    }

    /// L'etat affiche. Sans carte, c'est un brouillon, quel que soit le calcul.
    public static func state(cards: [CardState], now: Date = .now) -> State {
        guard !cards.isEmpty else { return .draft }
        let value = compute(cards: cards, now: now)
        if value >= DesignTokens.Freshness.acquired { return .acquired }
        if value >= DesignTokens.Freshness.toReview { return .toReview }
        return .endangered
    }
}
