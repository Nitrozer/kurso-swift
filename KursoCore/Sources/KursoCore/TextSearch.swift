import Foundation

/// Recherche dans le texte reconnu des pages.
///
/// Pure et generique sur l'element : ce module ne connait pas `Page`. La
/// reconnaissance elle-meme (Vision) vit cote application, seul le classement
/// est ici — c'est la partie qui a des regles, donc celle qui merite des tests.
public enum TextSearch {

    public struct Hit<Item>: Equatable where Item: Equatable {
        public let item: Item
        /// Plus le score est haut, plus le resultat remonte.
        public let score: Int
    }

    /// Normalise pour comparer : sans accents, sans casse.
    ///
    /// Un etudiant qui cherche « theoreme » doit trouver « théorème ». Taper les
    /// accents sur un clavier pendant un cours n'arrive pas.
    public static func normalize(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
    }

    /// Rend les elements dont le texte contient la requete, les meilleurs d'abord.
    ///
    /// Le classement suit trois rangs, du plus fort au plus faible :
    /// un mot entier, un debut de mot, puis n'importe ou dans le texte. Un
    /// etudiant qui cherche « tri » veut « tri fusion » avant « geometrie ».
    public static func rank<Item: Equatable>(
        _ items: [Item],
        query: String,
        text: (Item) -> String
    ) -> [Hit<Item>] {
        let needle = normalize(query).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return [] }

        return items.compactMap { item -> Hit<Item>? in
            let haystack = normalize(text(item))
            guard haystack.contains(needle) else { return nil }

            let words = haystack.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            if words.contains(where: { $0 == Substring(needle) }) {
                return Hit(item: item, score: 3)
            }
            if words.contains(where: { $0.hasPrefix(needle) }) {
                return Hit(item: item, score: 2)
            }
            return Hit(item: item, score: 1)
        }
        .sorted { $0.score > $1.score }
    }
}
