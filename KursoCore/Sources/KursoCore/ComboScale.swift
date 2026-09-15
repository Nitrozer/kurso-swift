import Foundation

/// L'echelle de combo, affichee pendant une session (§9).
///
/// Elle est montree en entier, y compris les crans qu'on n'a pas atteints :
/// savoir qu'il existe un ×4 a sept bonnes reponses est ce qui donne envie
/// d'enchainer. Un multiplicateur qu'on decouvre apres coup ne motive rien.
public enum ComboScale {

    public struct Step: Equatable, Sendable, Identifiable {
        /// Le multiplicateur d'XP.
        public let multiplier: Int
        /// Ce qu'il faut pour l'atteindre.
        public let label: String
        /// Bonnes reponses consecutives necessaires. Nil pour le cran final,
        /// qui ne s'obtient pas en comptant mais en ne ratant rien.
        public let streak: Int?

        public var id: Int { multiplier }
    }

    /// Les crans, dans l'ordre. Les seuils suivent `GameValues.combo`.
    public static let steps: [Step] = [
        .init(multiplier: 1, label: "départ", streak: 0),
        .init(multiplier: 2, label: "2 bonnes réponses", streak: 2),
        .init(multiplier: 3, label: "4 bonnes réponses", streak: 4),
        .init(multiplier: 4, label: "7 bonnes réponses", streak: 7),
        .init(multiplier: GameValues.perfectPageCombo, label: "sans faute sur le nœud", streak: nil),
    ]

    /// Le cran atteint pour une serie donnee.
    public static func step(forStreak streak: Int) -> Step {
        let combo = GameValues.combo(forStreak: streak)
        return steps.first { $0.multiplier == combo } ?? steps[0]
    }

    /// Ce qu'on perd sur une erreur, et ce qu'on ne perd pas.
    public static let warningTitle = "UNE ERREUR RAMÈNE À ×1"
    public static let warning = "Mais la carte ratée revient demain, en tête de pile. On perd le combo, jamais le travail."

    /// « 4 cartes restantes · 3 min »
    public static func remaining(answered: Int, total: Int, secondsPerCard: Int = 45) -> String {
        let left = max(0, total - answered)
        guard left > 0 else { return "Dernière carte" }
        let minutes = max(1, Int((Double(left * secondsPerCard) / 60).rounded()))
        return "\(left) carte\(left > 1 ? "s" : "") restante\(left > 1 ? "s" : "") · \(minutes) min"
    }
}
