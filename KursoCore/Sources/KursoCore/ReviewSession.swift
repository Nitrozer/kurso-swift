import Foundation

/// Le deroulement d'une session de revision (§9).
///
/// Type valeur teste hors interface : c'est ici que vivent le combo, les
/// gommes et la regle qui compte le plus — une session interrompue ne penalise
/// pas les cartes non vues.
public struct ReviewSession: Equatable, Sendable {

    public enum Outcome: Equatable, Sendable {
        case inProgress
        /// Toutes les cartes ont ete vues.
        case finished
        /// Plus de gommes : la session s'arrete, sans penaliser les dueAt.
        case outOfGommes
    }

    /// Huit cartes par session, vingt en mode partiel.
    public static let defaultSize = 8
    public static let examModeSize = 20

    public let cardCount: Int
    public let hasFullVersion: Bool

    public private(set) var index = 0
    /// Bonnes reponses consecutives, qui pilotent le combo.
    public private(set) var streak = 0
    public private(set) var gommes: Int
    public private(set) var xpEarned = 0
    public private(set) var mistakes = 0
    public private(set) var outcome: Outcome = .inProgress

    public var combo: Int { GameValues.combo(forStreak: streak) }
    /// Les cartes que la session n'a pas eu le temps de montrer.
    public var unseenCount: Int { max(0, cardCount - index) }
    /// Une session sans faute : c'est elle qui vaut le combo de page parfaite.
    public var isPerfect: Bool { mistakes == 0 }

    public init(cardCount: Int, gommes: Int, hasFullVersion: Bool = false) {
        self.cardCount = cardCount
        self.gommes = gommes
        self.hasFullVersion = hasFullVersion
    }

    /// Enregistre une reponse. Rend l'XP gagne sur cette carte.
    @discardableResult
    public mutating func answer(_ answer: SpacedRepetition.Answer, isSprint: Bool = false) -> Int {
        guard outcome == .inProgress else { return 0 }

        var gained = 0
        switch answer {
        case .knew, .almost:
            streak += 1
            gained = GameValues.xpForCard(combo: combo, isSprint: isSprint)
            xpEarned += gained

        case .failed:
            mistakes += 1
            // Une erreur ramene le combo a ×1 et coute une gomme.
            streak = 0
            gommes = GameValues.gommesAfterMistake(gommes, hasFullVersion: hasFullVersion)
        }

        index += 1

        if gommes == 0 && !hasFullVersion {
            // On perd le combo, jamais le travail : les cartes non vues gardent
            // leur dueAt, elles reviendront comme prevu.
            outcome = .outOfGommes
        } else if index >= cardCount {
            outcome = .finished
        }
        return gained
    }
}
