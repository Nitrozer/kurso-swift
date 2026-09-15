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

    /// L'extrait a montrer pour un resultat : la ligne qui contient le terme,
    /// et ou le surligner.
    ///
    /// Montrer la vignette d'une page ne dit pas OU le mot a ete trouve. C'est
    /// pourtant tout l'interet de chercher dans sa propre ecriture : voir la
    /// phrase qu'on avait ecrite, avec le mot dedans.
    public struct Excerpt: Equatable, Sendable {
        public let line: String
        /// Les morceaux a surligner, en indices de caracteres de `line`.
        public let highlights: [Range<Int>]

        public init(line: String, highlights: [Range<Int>]) {
            self.line = line
            self.highlights = highlights
        }
    }

    /// La premiere ligne contenant le terme, decoupee pour l'affichage.
    ///
    /// La comparaison se fait sur le texte normalise — « theoreme » doit
    /// surligner « théorème » — mais les indices rendus portent sur le texte
    /// d'origine, qu'on affiche tel quel.
    public static func excerpt(from text: String, query: String, limit: Int = 120) -> Excerpt? {
        let needle = normalize(query).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return nil }

        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            let haystack = Array(normalize(line))
            let target = Array(needle)
            guard haystack.count >= target.count else { continue }

            var found: [Range<Int>] = []
            var index = 0
            while index <= haystack.count - target.count {
                if Array(haystack[index..<(index + target.count)]) == target {
                    found.append(index..<(index + target.count))
                    index += target.count
                } else {
                    index += 1
                }
            }
            guard !found.isEmpty else { continue }

            // Une ligne entiere de cours est trop longue pour une rangee : on
            // la coupe, sans jamais couper au milieu d'un surlignage.
            let characters = Array(line)
            guard characters.count > limit, let first = found.first else {
                return Excerpt(line: line, highlights: found)
            }
            let start = max(0, min(first.lowerBound - 30, characters.count - limit))
            let end = min(characters.count, start + limit)
            let shifted = found
                .filter { $0.lowerBound >= start && $0.upperBound <= end }
                .map { ($0.lowerBound - start)..<($0.upperBound - start) }
            let prefix = start > 0 ? "…" : ""
            let suffix = end < characters.count ? "…" : ""
            let offset = prefix.count
            return Excerpt(
                line: prefix + String(characters[start..<end]) + suffix,
                highlights: shifted.map { ($0.lowerBound + offset)..<($0.upperBound + offset) }
            )
        }
        return nil
    }
}
