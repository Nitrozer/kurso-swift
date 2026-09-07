import Foundation

/// Jetons de design du §13 de PASSATION.md.
///
/// Volontairement exprimes en hexadecimal brut plutot qu'en `Color` : ce module
/// n'importe aucune bibliotheque d'interface (§11bis). La couche SwiftUI fera
/// la conversion.
public enum DesignTokens {
    public enum Palette {
        public static let brand        = "#3B5BFF"   // Marque
        public static let ink          = "#131A33"   // Graphite / encre
        public static let reward       = "#FFD24D"   // Recompense
        public static let success      = "#17B26A"   // Reussite
        public static let alert        = "#B3242A"   // Alerte (fond)
        public static let alertOnDark  = "#FF8A8F"   // Alerte (sur sombre)
        public static let paper        = "#F6F8FF"   // Papier
        public static let paperAlt     = "#FFFFFF"   // Papier alt
        public static let eraser       = "#FF8FA3"   // Gomme
        public static let ferrule      = "#C9CFE0"   // Virole
        public static let fadedInk     = "#B8934A"   // Encre palie
        public static let gribouBody   = "#FFD24D"   // Corps Gribou
    }

    /// Seuils de fraicheur du §3. Partages par l'app, la carte et l'export.
    public enum Freshness {
        public static let acquired = 0.75   // >= : acquise
        public static let toReview = 0.40   // >= : a revoir, sinon a sauver

        /// L'encre du manuscrit ne descend jamais sous 0.35 : elle doit rester lisible.
        public static func inkOpacity(forFreshness freshness: Double) -> Double {
            0.35 + 0.65 * min(max(freshness, 0), 1)
        }
    }

    public enum Motion {
        /// « rien au-dela de 600 ms » — §13.
        public static let maxDurationSeconds = 0.6
    }
}
