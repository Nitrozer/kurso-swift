import Foundation

/// Regroupement des creneaux en matieres (§6).
///
/// Un emploi du temps ne dit pas quelles sont les matieres : il donne des
/// intitules qui varient d'une semaine a l'autre — « Algorithmique - CM »,
/// « ALGORITHMIQUE avancee TD gr.2 ». On les rapproche par similarite, puis
/// l'utilisateur valide : jamais de regroupement impose en silence.
public enum CourseGrouping {

    /// Seuil de similarite normalisee au-dela duquel deux intitules designent
    /// la meme matiere.
    public static let threshold = 0.85

    public struct Group: Equatable, Sendable {
        /// L'intitule le plus frequent du groupe, propose comme nom de matiere.
        public let name: String
        public let uids: [String]
        public let occurrences: Int
    }

    public static func group(_ events: [ICSEvent]) -> [Group] {
        var buckets: [(key: String, names: [String], uids: [String])] = []

        for event in events {
            let key = normalize(event.summary)
            guard !key.isEmpty else { continue }

            if let index = buckets.firstIndex(where: { similarity($0.key, key) >= threshold }) {
                buckets[index].names.append(event.summary)
                buckets[index].uids.append(event.uid)
            } else {
                buckets.append((key, [event.summary], [event.uid]))
            }
        }

        return buckets.map { bucket in
            Group(name: mostCommon(bucket.names), uids: bucket.uids, occurrences: bucket.names.count)
        }
        .sorted { $0.occurrences > $1.occurrences }
    }

    /// Sans accents, sans casse, sans ponctuation : « Algorithmique » et
    /// « ALGORITHMIQUE, » doivent tomber dans le meme groupe avant meme le calcul.
    static func normalize(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// Similarite normalisee : 1 pour deux chaines identiques, 0 pour deux
    /// chaines sans rien de commun.
    public static func similarity(_ a: String, _ b: String) -> Double {
        if a == b { return 1 }
        let longest = max(a.count, b.count)
        guard longest > 0 else { return 1 }
        return 1 - Double(levenshtein(Array(a), Array(b))) / Double(longest)
    }

    /// Distance d'edition, en ne gardant que deux lignes de la matrice : un
    /// emploi du temps de semestre compte des centaines de creneaux.
    static func levenshtein(_ a: [Character], _ b: [Character]) -> Int {
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }

        var previous = Array(0...b.count)
        var current = [Int](repeating: 0, count: b.count + 1)

        for i in 1...a.count {
            current[0] = i
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
            }
            swap(&previous, &current)
        }
        return previous[b.count]
    }

    private static func mostCommon(_ names: [String]) -> String {
        var counts: [String: Int] = [:]
        for name in names { counts[name, default: 0] += 1 }
        // A egalite, le plus court : « Algorithmique » plutot que
        // « Algorithmique - CM - amphi B ».
        return counts.max { lhs, rhs in
            lhs.value != rhs.value ? lhs.value < rhs.value : lhs.key.count > rhs.key.count
        }?.key ?? names.first ?? ""
    }
}
