import Foundation

/// Jetons de la direction artistique « l'autocollant ».
///
/// Chaque teinte a un sens unique — aucune n'est decorative. Les valeurs sont
/// des chaines hexadecimales : ce module n'importe aucune bibliotheque
/// d'interface (§11bis), la couche SwiftUI fait la conversion.
public enum DesignTokens {

    public enum Palette {
        /// Le cours en direct, les liens, l'accent.
        public static let brand       = "#3B5BFF"
        /// Toutes les bordures, tout le texte.
        public static let ink         = "#131A33"
        /// Bouton principal, XP, coffre. Ne porte JAMAIS de texte clair.
        public static let reward      = "#FFD24D"
        /// Coche, page acquise, valider.
        public static let success     = "#17B26A"
        /// Alerte en FOND, portant du texte blanc.
        public static let alertBg     = "#B3242A"
        /// Alerte en TEXTE, sur fond sombre. Intervertir les deux casse le contraste.
        public static let alertOnDark = "#FF8A8F"
        /// La serie, et rien d'autre.
        public static let flame       = "#FF6B1A"
        /// Les vies, la gomme de Gribou.
        public static let eraser      = "#FF8FA3"
        /// Page a revoir.
        public static let fadedInk    = "#B8934A"
        /// Page a sauver.
        public static let endangered  = "#E5484D"
        /// Fond de tous les ecrans.
        public static let paper       = "#F6F8FF"
        public static let paperAlt    = "#FFFFFF"

        // Neutres de structure.
        /// Texte secondaire.
        public static let inkSoft     = "#4C5470"
        /// Texte de corps legerement adouci.
        public static let inkBody     = "#3A4368"
        /// Fond d'un autocollant « fait ».
        public static let doneFill    = "#E8EBF7"
        /// Contour pointille d'un autocollant « a venir ».
        public static let pendingLine = "#A9B0C9"
        /// Separateurs internes.
        public static let hairline    = "#EEF1FC"
    }

    /// L'autocollant : le composant de base, tout en decoule.
    public enum Sticker {
        public static let borderWidth: Double = 3
        /// Rayon selon la taille du bloc.
        public static let radiusSmall: Double = 14
        public static let radiusLarge: Double = 26
        /// Ombre AU REPOS : decalee, jamais floutee.
        public static let shadowRest: Double = 5
        /// Ombre PRESSE : elle se comprime, le bloc descend de 3 px.
        public static let shadowPressed: Double = 2
        public static let pressOffset: Double = 3
    }

    /// Seuils de fraicheur (§3). Le mot accompagne toujours la couleur : aucune
    /// information ne repose sur la seule teinte.
    public enum Freshness {
        public static let acquired = 0.75
        public static let toReview = 0.40

        /// L'encre ne descend jamais sous 0.35 : une note oubliee reste lisible.
        /// On palit, on n'efface pas.
        public static func inkOpacity(forFreshness freshness: Double) -> Double {
            0.35 + 0.65 * min(max(freshness, 0), 1)
        }
    }

    /// Tout a ressort, rien en lineaire. Rien ne depasse 600 ms hors boucles.
    public enum Motion {
        public static let pressSeconds     = 0.14
        public static let screenInSeconds  = 0.30
        public static let levelNumSeconds  = 0.52
        public static let chestSeconds     = 0.60
        public static let maxSeconds       = 0.60
        // Boucles d'attente, seules autorisees au-dela.
        public static let flameLoopSeconds  = 1.5
        public static let gribouLoopSeconds = 2.6
    }

    /// Interlettrage des metadonnees en capitales.
    public enum Typography {
        public static let monoTracking = 0.12
    }
}
