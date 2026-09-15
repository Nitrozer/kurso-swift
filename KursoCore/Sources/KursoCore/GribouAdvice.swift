import Foundation

/// Ce que Gribou dit, et surtout ce qu'il ne dit pas (§12).
///
/// Le §12 le plafonne a trois apparitions par session. Ce n'est pas une
/// limitation technique : une mascotte qui commente tout devient un bruit de
/// fond qu'on cesse de lire, et c'est ce qui separe Kurso d'une application
/// pour enfants. Le budget etant serre, le choix compte plus que l'ecriture —
/// d'ou ce module, qui arbitre.
///
/// La regle absolue reste ailleurs (`Gribou.mood`) : jamais un mot pendant
/// que le stylet ecrit.
public enum GribouAdvice {

    /// Le registre d'un conseil, du plus utile au plus dispensable.
    ///
    /// L'ordre des valeurs EST la priorite : quand la place manque, le plus
    /// haut gagne.
    public enum Kind: Int, Sendable, Equatable, Comparable, CaseIterable {
        /// Du ton, pas de l'information.
        case cheer = 0
        /// Une mecanique du jeu, expliquee une seule fois dans la vie.
        case mechanic = 1
        /// Ce qui vient de se passer, commente.
        case debrief = 2
        /// Un fait qui appelle un geste aujourd'hui.
        case action = 3

        public static func < (a: Kind, b: Kind) -> Bool { a.rawValue < b.rawValue }
    }

    public struct Tip: Equatable, Sendable, Identifiable {
        /// Stable d'une session a l'autre : c'est lui qui retient qu'une
        /// mecanique a deja ete expliquee.
        public let id: String
        public let kind: Kind
        public let text: String

        public init(id: String, kind: Kind, text: String) {
            self.id = id
            self.kind = kind
            self.text = text
        }

        /// Une mecanique ne s'explique qu'une fois. Le reste peut revenir.
        public var isOnceInALifetime: Bool { kind == .mechanic }
    }

    /// Le conseil a montrer, ou nil s'il vaut mieux se taire.
    ///
    /// - Parameters:
    ///   - candidates: ce que l'ecran courant aurait a dire.
    ///   - spent: apparitions deja consommees dans cette session.
    ///   - seen: identifiants des mecaniques deja expliquees, pour toujours.
    public static func choose(
        from candidates: [Tip],
        spent: Int,
        seen: Set<String> = []
    ) -> Tip? {
        guard Gribou.canAppear(appearancesSoFar: spent) else { return nil }
        return candidates
            .filter { !($0.isOnceInALifetime && seen.contains($0.id)) }
            // Tri stable : a registre egal, l'ordre de declaration decide,
            // ce qui laisse l'ecran ranger ses propres conseils.
            .enumerated()
            .max { left, right in
                left.element.kind == right.element.kind
                    ? left.offset > right.offset
                    : left.element.kind < right.element.kind
            }?
            .element
    }

    /// Ce qu'il reste de budget, pour l'afficher si besoin.
    public static func remaining(spent: Int) -> Int {
        max(0, Gribou.maxAppearancesPerSession - spent)
    }
}
