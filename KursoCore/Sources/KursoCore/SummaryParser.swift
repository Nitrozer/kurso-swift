import Foundation

/// Decoupage d'un intitule de creneau.
///
/// Les ENT n'ont pas de champ « matiere » : ils empilent tout dans SUMMARY.
/// Un export ADE donne « Langues Cours magistral ARTHEY Caroline », ou la
/// matiere, le type de seance et l'enseignant se suivent sans separateur.
/// Sans decoupage, chaque enseignant creerait sa propre matiere.
public enum SummaryParser {

    public struct Parts: Equatable, Sendable {
        public let subject: String
        public let sessionType: String?
        public let teacher: String?
    }

    /// Types de seance rencontres dans les exports francais, du plus long au
    /// plus court : « Travaux dirigés » doit etre teste avant « TD ».
    static let sessionTypes = [
        "Travail en Autonomie", "Travaux Pratiques", "Travaux Diriges", "Travaux Dirigés",
        "Cours Magistral", "Controle Continu", "Contrôle Continu",
        "Projet", "Conference", "Conférence", "Examen", "Partiel", "Soutenance",
        "CM", "TD", "TP", "TA", "CC",
    ]

    public static func parse(_ summary: String) -> Parts {
        var text = summary
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Le type de seance part en premier : une abreviation comme « CM » est
        // en capitales et serait sinon avalee par le nom de l'enseignant.
        let sessionType = extractSessionType(&text)
        let teacher = extractTeacher(&text)

        let subject = collapse(text)
        // Si le decoupage ne laisse rien, l'intitule d'origine vaut mieux qu'un vide.
        return Parts(
            subject: subject.isEmpty ? collapse(summary) : subject,
            sessionType: sessionType,
            teacher: teacher
        )
    }

    /// L'enseignant ferme l'intitule, sous la forme NOM Prenom : un mot en
    /// capitales suivi d'un ou deux mots capitalises.
    private static func extractTeacher(_ text: inout String) -> String? {
        // NOM en capitales (eventuellement compose : LE GALL), suivi d'un a deux
        // prenoms capitalises pouvant etre composes (Jean-Pierre).
        let pattern = #"\s+(\p{Lu}[\p{Lu}\-']+(?:\s+\p{Lu}[\p{Lu}\-']+)*(?:\s+\p{Lu}[\p{Ll}']*(?:-\p{Lu}?[\p{Ll}']+)*){1,2})\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text)
        else { return nil }

        let name = String(text[range])
        text.removeSubrange(Range(match.range, in: text)!)
        return name
    }

    /// Retire un type de seance, une seule occurrence : « Travail en Autonomie
    /// Travail en Autonomie » doit rendre la matiere, pas une chaine vide.
    private static func extractSessionType(_ text: inout String) -> String? {
        for type in sessionTypes {
            guard let range = text.range(of: type, options: [.caseInsensitive, .diacriticInsensitive]) else { continue }
            let remainder = collapse(text.replacingCharacters(in: range, with: " "))
            guard !remainder.isEmpty else { continue }
            text = remainder
            return type
        }
        return nil
    }

    private static func collapse(_ text: String) -> String {
        text.split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
