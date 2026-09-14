import Foundation

/// L'ordre des pages dans un cahier.
///
/// Le §12 interdit les dossiers et les arborescences — l'emploi du temps
/// range. Mais DANS un cahier, l'etudiant decide : une page manuscrite, puis
/// deux diapos, puis une photo, puis la suite du cours. C'est une sequence,
/// pas une hierarchie.
///
/// Les rangs sont des nombres a virgule : inserer entre deux voisins revient
/// a prendre leur milieu, sans renumeroter tout le cahier a chaque fois.
public enum PageOrdering {

    /// Ecart entre deux pages ajoutees a la suite.
    public static let step: Double = 1_000

    /// Le rang d'une page glissee entre ces deux voisins.
    ///
    /// - Parameters:
    ///   - after: le rang du voisin du dessus, ou `nil` pour le tout debut.
    ///   - before: le rang du voisin du dessous, ou `nil` pour la fin.
    public static func position(after: Double?, before: Double?) -> Double {
        switch (after, before) {
        case let (a?, b?):  (a + b) / 2
        case let (a?, nil): a + step
        case let (nil, b?): b - step
        case (nil, nil):    0
        }
    }

    /// Le rang d'une page ajoutee a la fin.
    public static func append(to positions: [Double]) -> Double {
        position(after: positions.max(), before: nil)
    }

    /// Deux rangs finissent par se rejoindre a force de couper en deux.
    /// Au-dela, on renumerote proprement.
    public static let minimumGap: Double = 0.000_001

    public static func needsRenumbering(_ positions: [Double]) -> Bool {
        let sorted = positions.sorted()
        return zip(sorted, sorted.dropFirst()).contains { $1 - $0 < minimumGap }
    }

    /// Des rangs bien espaces, dans l'ordre donne.
    public static func renumbered(count: Int) -> [Double] {
        (0..<count).map { Double($0) * step }
    }
}
