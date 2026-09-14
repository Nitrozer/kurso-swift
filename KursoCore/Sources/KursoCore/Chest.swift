import Foundation

/// Le coffre de passage de niveau (§9, §11 etape 4).
///
/// Il se GAGNE, il ne s'achete pas et ne se joue pas : le §12 a retire le pari
/// de copeaux, et interdit tout ce qui fait progresser plus vite. Un coffre ne
/// donne donc que des copeaux et, de temps en temps, une couverture.
///
/// Son contenu est determine par le niveau, pas tire au sort. Deux etudiants
/// au meme niveau recoivent la meme chose : personne ne relance l'application
/// en esperant mieux.
public enum Chest {

    /// Copeaux d'un coffre de niveau `level`.
    ///
    /// Croissant, mais sans emballement : le but est de payer une couverture
    /// de temps en temps, pas de rendre les copeaux sans valeur.
    public static func shavings(forLevel level: Int) -> Int {
        guard level > 1 else { return 0 }
        return 60 + (level - 2) * 20
    }

    /// Un coffre sur trois apporte une couverture, s'il en reste a decouvrir.
    public static func cover(forLevel level: Int, owned: Set<String>) -> Shop.Cover? {
        guard level > 1, level % 3 == 0 else { return nil }
        return Shop.Cover.allCases.first { $0.price > 0 && !owned.contains($0.rawValue) }
    }

    /// Le §9 n'autorise que deux gels en reserve.
    public static let maxFreezes = 2

    /// Un gel de serie par coffre, plafonne a la reserve autorisee.
    ///
    /// Un gel ne fait pas progresser plus vite : il evite de perdre une serie,
    /// il ne fait rien gagner. C'est a ce titre qu'il tient dans un coffre
    /// sans contredire le §12.
    public static func freezes(inReserve: Int, chests: Int) -> Int {
        max(0, min(maxFreezes, inReserve + max(0, chests)) - inReserve)
    }

    /// Les niveaux dont le coffre n'a pas encore ete ouvert.
    ///
    /// On rattrape les niveaux passes : monter de deux d'un coup pendant une
    /// grosse session ne doit pas faire perdre un coffre.
    public static func pending(currentLevel: Int, lastOpened: Int) -> [Int] {
        guard currentLevel > max(lastOpened, 1) else { return [] }
        return Array((max(lastOpened, 1) + 1)...currentLevel)
    }
}
