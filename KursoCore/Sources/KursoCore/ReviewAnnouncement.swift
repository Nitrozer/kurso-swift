import Foundation

/// Ce que Kurso repond a voix haute quand on lui demande le travail du jour.
///
/// Pure exprès (§11bis) : une phrase parlee se relit mal dans un simulateur,
/// et c'est le genre de detail qu'on casse sans s'en apercevoir.
public enum ReviewAnnouncement {

    /// La phrase dite par Siri pour un nombre de cartes dues.
    public static func sentence(due: Int) -> String {
        switch due {
        case ...0: "Rien à réviser pour l'instant."
        case 1:    "Une carte t'attend."
        default:   "\(due) cartes t'attendent."
        }
    }

    /// La phrase dite en ouvrant un cahier.
    public static func opening(_ cahier: String) -> String {
        cahier.isEmpty ? "J'ouvre ton cahier." : "J'ouvre \(cahier)."
    }
}
