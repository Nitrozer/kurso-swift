import Foundation

/// Les copeaux et ce qu'ils achetent (§9).
///
/// **Jamais d'avance.** Aucun article ne donne de gomme, d'XP, de temps ni de
/// carte : le §12 l'interdit, et une application qui vend de la progression
/// cesse d'etre un outil de travail. On n'achete que des couvertures de cahier.
public enum Shop {

    /// Gains, tels que le §9 les fixe.
    public enum Earn {
        public static let correctCard = 8
        public static let finishedPage = 40
        public static let masteredNode = 120
    }

    /// Une couverture de cahier. Rien d'autre n'est a vendre.
    public enum Cover: String, CaseIterable, Sendable {
        case plain, stripes, grid, kraft, marble

        public var label: String {
            switch self {
            case .plain:   "Uni"
            case .stripes: "Rayé"
            case .grid:    "Quadrillé"
            case .kraft:   "Kraft"
            case .marble:  "Marbré"
            }
        }

        /// L'uni est donne : un cahier doit avoir une couverture sans payer.
        public var price: Int {
            switch self {
            case .plain:   0
            case .stripes: 120
            case .grid:    120
            case .kraft:   240
            case .marble:  400
            }
        }

        public static func named(_ raw: String) -> Cover {
            Cover(rawValue: raw) ?? .plain
        }
    }

    public static func isOwned(_ cover: Cover, owned: Set<String>) -> Bool {
        cover.price == 0 || owned.contains(cover.rawValue)
    }

    public static func canBuy(_ cover: Cover, shavings: Int, owned: Set<String>) -> Bool {
        !isOwned(cover, owned: owned) && shavings >= cover.price
    }

    /// Les copeaux restants apres l'achat. Rend nil si l'achat n'a pas lieu —
    /// on ne debite jamais sans livrer.
    public static func buy(_ cover: Cover, shavings: Int, owned: Set<String>) -> Int? {
        guard canBuy(cover, shavings: shavings, owned: owned) else { return nil }
        return shavings - cover.price
    }
}
