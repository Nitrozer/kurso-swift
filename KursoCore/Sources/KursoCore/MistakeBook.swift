import Foundation

/// Le carnet des ratés (§2).
///
/// Une carte y entre a deux echecs cumules. A dix cartes, le carnet devient un
/// « boss » : le vider entierement en une seule session donne une fiche or et
/// remet les compteurs d'echec a zero.
public enum MistakeBook {

    /// Seuil au-dela duquel le carnet devient un boss.
    public static let bossThreshold = 10

    public static func contains(lapses: Int) -> Bool {
        lapses >= SpacedRepetition.mistakeBookThreshold
    }

    public static func isBoss(count: Int) -> Bool {
        count >= bossThreshold
    }

    /// Ce que rapporte une session de carnet.
    public struct Reward: Equatable, Sendable {
        /// Vrai seulement si TOUTES les cartes du carnet ont ete vues et reussies.
        public let clearedEntirely: Bool
        /// La fiche or n'arrive que pour un boss vide en entier.
        public let goldCard: Bool
    }

    /// Evalue une session de carnet.
    ///
    /// Vider le carnet ne suffit pas : il faut l'avoir vide *en une session*.
    /// Une carte ratee au passage laisse le carnet ouvert, sinon la recompense
    /// se donnerait a force d'essais plutot que de maitrise.
    public static func evaluate(
        bookSize: Int,
        answered: Int,
        failures: Int
    ) -> Reward {
        let cleared = bookSize > 0 && answered >= bookSize && failures == 0
        return Reward(clearedEntirely: cleared, goldCard: cleared && isBoss(count: bookSize))
    }
}
