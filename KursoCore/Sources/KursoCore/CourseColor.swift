import Foundation

/// La couleur d'un cahier.
///
/// « Une couleur par matiere, et c'est tout » : c'est le seul rangement que
/// l'etudiant regle a la main. Le §12 interdit les dossiers et les tags — une
/// couleur ne classe rien, elle aide juste l'oeil a retrouver son cahier.
public enum CourseColor: String, CaseIterable, Sendable {
    case blue, green, pink, yellow, grey

    /// Le jeton tel qu'il est enregistre.
    public var token: String { rawValue }

    public var label: String {
        switch self {
        case .blue:   "Bleu"
        case .green:  "Vert"
        case .pink:   "Rose"
        case .yellow: "Jaune"
        case .grey:   "Gris"
        }
    }

    public static func named(_ token: String) -> CourseColor {
        CourseColor(rawValue: token) ?? .blue
    }

    /// Une couleur differente pour chaque matiere importee.
    ///
    /// Les cinq se suivent puis recommencent : au-dela, deux matieres
    /// partagent une teinte, ce qui vaut mieux qu'inventer des couleurs
    /// hors de la direction artistique.
    public static func forIndex(_ index: Int) -> CourseColor {
        let all = CourseColor.allCases
        return all[((index % all.count) + all.count) % all.count]
    }
}
