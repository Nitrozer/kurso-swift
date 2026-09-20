import Foundation

/// Les intercalaires d'un cahier.
///
/// Le §12 interdit « dossiers, tags ni arborescence a creer a la main », et la
/// raison est donnee juste apres : « l'emploi du temps range ». Cette regle
/// vise le rangement par MATIERE, celui qu'on n'a plus a faire. Un
/// intercalaire ne range pas une page dans une matiere : il dit ce qu'elle
/// est, a l'interieur d'un cahier qui a deja sa matiere.
///
/// La liste est donc FERMEE. Rien a creer, rien a nommer, rien a maintenir :
/// on pose un intercalaire ou on ne le pose pas. C'est ce qui separe un
/// intercalaire d'une arborescence — l'un se choisit, l'autre se construit.
public enum PageTag: String, CaseIterable, Sendable, Codable {
    case cours
    case exercice
    case td
    case correction

    public var label: String {
        switch self {
        case .cours:      "Cours"
        case .exercice:   "Exercice"
        case .td:         "TD"
        case .correction: "Correction"
        }
    }

    /// Le jeton de couleur de l'intercalaire. Pris dans la palette du §13,
    /// jamais choisi librement.
    public var colorToken: String {
        switch self {
        case .cours:      DesignTokens.Palette.brand
        case .exercice:   DesignTokens.Palette.reward
        case .td:         DesignTokens.Palette.eraser
        case .correction: DesignTokens.Palette.success
        }
    }

    public static func named(_ raw: String) -> PageTag? {
        PageTag(rawValue: raw)
    }

    /// Combien de pages portent cet intercalaire.
    public static func count(_ tag: PageTag, in tags: [String]) -> Int {
        tags.filter { $0 == tag.rawValue }.count
    }

    /// Les intercalaires a montrer : uniquement ceux qui portent une page.
    ///
    /// Un onglet vide n'est pas un rangement, c'est une promesse non tenue —
    /// et quatre onglets gris en permanence donneraient au cahier l'air d'un
    /// classeur a remplir.
    public static func dividers(for tags: [String]) -> [PageTag] {
        allCases.filter { count($0, in: tags) > 0 }
    }

    /// Les pages de cet intercalaire, dans l'ordre donne.
    ///
    /// `nil` rend tout : « Tout » n'est pas un intercalaire, c'est son
    /// absence.
    public static func keep<T>(_ items: [T], matching tag: PageTag?,
                               tagOf: (T) -> String) -> [T] {
        guard let tag else { return items }
        return items.filter { tagOf($0) == tag.rawValue }
    }

    /// Un intercalaire qui ne porte plus rien ne doit pas rester selectionne :
    /// on se retrouverait devant un cahier vide sans comprendre pourquoi.
    public static func stillThere(_ tag: PageTag?, in tags: [String]) -> PageTag? {
        guard let tag, count(tag, in: tags) > 0 else { return nil }
        return tag
    }
}
