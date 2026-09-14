import Foundation

/// Les fiches a collectionner (§11, etape 4).
///
/// Une fiche par page : on la gagne en maitrisant ce qu'on y a ecrit. Elle ne
/// s'achete pas et ne se tire pas au sort — le §12 interdit tout achat qui
/// fait progresser plus vite, et une collection qui se paie n'apprend rien.
public enum Fiche {

    public enum Rarity: String, Sendable, CaseIterable, Equatable {
        /// Rien a maitriser encore : la page n'a pas de carte.
        case locked
        case common
        case rare
        /// Tout su, et jamais rate.
        case gold

        public var label: String {
            switch self {
            case .locked: "VERROUILLÉE"
            case .common: "COMMUNE"
            case .rare:   "RARE"
            case .gold:   "OR · SANS FAUTE"
            }
        }

        /// Le nom court, pour les filtres.
        public var shortLabel: String {
            switch self {
            case .locked: "VERROUILLÉE"
            case .common: "COMMUNE"
            case .rare:   "RARE"
            case .gold:   "OR"
            }
        }

        /// Pastilles allumees sur la fiche, de 0 a 3.
        public var dots: Int {
            switch self {
            case .locked: 0
            case .common: 1
            case .rare:   2
            case .gold:   3
            }
        }
    }

    /// Seuil a partir duquel une page compte comme largement sue.
    public static let rareThreshold = 0.7

    /// Intervalle a partir duquel une carte est consideree sue.
    ///
    /// Trois semaines : c'est le seuil classique de la repetition espacee.
    /// On ne peut pas se fier a la fraicheur (§3), qui mesure le RETARD — une
    /// carte creee a l'instant n'est jamais en retard, et passerait pour sue.
    public static let matureInterval = 21

    /// Cette carte est-elle sue ? Un long intervalle, et pas de retard.
    public static func isAcquired(interval: Int, dueAt: Date, now: Date = .now) -> Bool {
        interval >= matureInterval && dueAt >= now
    }

    /// La rarete d'une fiche, d'apres les cartes de sa page.
    ///
    /// - Parameters:
    ///   - cardCount: nombre de cartes de la page.
    ///   - acquired: combien sont acquises.
    ///   - lapses: total des ratés sur ces cartes.
    public static func rarity(cardCount: Int, acquired: Int, lapses: Int) -> Rarity {
        guard cardCount > 0 else { return .locked }
        let ratio = Double(min(acquired, cardCount)) / Double(cardCount)
        if ratio >= 1, lapses == 0 { return .gold }
        if ratio >= rareThreshold { return .rare }
        return .common
    }

    /// Ce qu'on annonce en haut : « 6 sur 18 · 2 en or ».
    public static func summary(_ rarities: [Rarity]) -> String {
        let unlocked = rarities.filter { $0 != .locked }.count
        let gold = rarities.filter { $0 == .gold }.count
        let total = rarities.count
        var text = "\(unlocked) sur \(total)"
        if gold > 0 { text += " · \(gold) en or" }
        return text.uppercased()
    }
}
