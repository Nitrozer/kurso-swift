import Foundation
import SwiftData

public enum AbbreviationSource: String, Codable, Sendable {
    /// Liste integree (~120 entrees).
    case builtinList
    /// Paire deduite quand une page contient l'abrege manuscrit et le mot complet tape.
    case learnedFromMac
    /// Confirmee par l'etudiant, une seule fois, en fin de seance.
    case userConfirmed
}

/// Le dictionnaire ne sert qu'a la recherche et aux propositions de cartes.
/// Il ne modifie JAMAIS le contenu d'une page (§4).
@Model public final class Abbreviation {
    public var id: UUID = UUID()
    public var shortForm: String = ""
    public var longForm: String = ""
    public var sourceRaw: String = AbbreviationSource.builtinList.rawValue

    public var source: AbbreviationSource {
        get { AbbreviationSource(rawValue: sourceRaw) ?? .builtinList }
        set { sourceRaw = newValue.rawValue }
    }

    public init(shortForm: String = "", longForm: String = "", source: AbbreviationSource = .builtinList) {
        self.shortForm = shortForm
        self.longForm = longForm
        self.sourceRaw = source.rawValue
    }
}
