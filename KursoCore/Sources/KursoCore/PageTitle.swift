import Foundation

/// Titre d'une page, derive de sa premiere ligne (§4).
///
/// « Premiere ligne reconnue, tronquee a 60 caracteres, sans ponctuation finale.
/// Si l'etudiant l'edite, `titleWasEdited = true` et on n'y retouche plus jamais. »
///
/// La meme regle sert a deux sources : la reconnaissance manuscrite et la
/// premiere ligne du markdown tape sur Mac. D'ou sa place ici plutot que dans
/// l'une des deux vues.
public enum PageTitle {

    public static let maxLength = 60

    /// Ponctuation retiree en fin de titre. Les caracteres fermants comme `)`
    /// ou `»` restent : les enlever amputerait un titre legitime.
    private static let trailingPunctuation = CharacterSet(charactersIn: ".,;:!?…-–— \t")

    /// Rend le titre derive du texte, ou `nil` si rien d'exploitable.
    ///
    /// `nil` plutot qu'une chaine vide : l'appelant doit pouvoir distinguer
    /// « pas de titre a proposer » de « titre vide », et ne jamais ecraser un
    /// titre existant avec du vide.
    public static func derive(from text: String) -> String? {
        guard let rawLine = text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
        else { return nil }

        var line = String(rawLine).trimmingCharacters(in: .whitespaces)

        // Les dieses d'un titre markdown ne font pas partie du titre.
        while line.hasPrefix("#") { line.removeFirst() }
        line = line.trimmingCharacters(in: .whitespaces)

        if line.count > maxLength {
            line = String(line.prefix(maxLength))
        }

        while let last = line.unicodeScalars.last, trailingPunctuation.contains(last) {
            line.removeLast()
        }

        return line.isEmpty ? nil : line
    }
}

public extension PageTitle {
    /// Retire le « — 3 » d'un titre de diapo.
    ///
    /// Les diapos d'un PDF sont numerotees une par une, mais les cahiers n'en
    /// montrent qu'une entree : le numero n'y veut plus rien dire.
    static func withoutSlideNumber(_ title: String) -> String {
        guard let separator = title.range(of: " — ", options: .backwards) else { return title }
        let tail = title[separator.upperBound...]
        guard !tail.isEmpty, tail.allSatisfy(\.isNumber) else { return title }
        return String(title[..<separator.lowerBound])
    }
}
