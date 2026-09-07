import Foundation

/// Detection des devoirs dans les notes (§5).
///
/// Sans modele de langage : `NSDataDetector` pour les dates, une liste de
/// marqueurs pour l'obligation. Le §12 l'exige, et des regles sont ici plus
/// fiables — elles ne se trompent jamais de facon surprenante.
public enum TaskDetector {

    /// Marqueurs d'obligation du §5. Les plus longs d'abord, pour que
    /// « pour demain » soit reconnu avant « pour le ».
    public static let markers = [
        "à rendre", "a rendre", "pour demain", "pour le", "à faire", "a faire",
        "devoir", "exposé", "expose", "partiel", "contrôle", "controle",
        "rendu", "DM", "TD", "TP",
    ]

    /// Heure retenue quand la ligne ne dit pas d'heure.
    public static let defaultHour = 18

    public struct Proposal: Equatable, Sendable {
        public let title: String
        public let dueAt: Date
        /// Le marqueur qui a declenche la proposition : c'est lui qu'on
        /// desactive apres trois refus.
        public let marker: String
        public let lineIndex: Int
    }

    /// Analyse un texte ligne par ligne.
    ///
    /// `disabledMarkers` porte la regle des faux positifs : trois refus sur le
    /// meme marqueur et il ne propose plus rien, sans reglage ni message.
    public static func detect(
        in text: String,
        now: Date = .now,
        calendar: Calendar = .current,
        disabledMarkers: Set<String> = []
    ) -> [Proposal] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else {
            return []
        }

        var proposals: [Proposal] = []
        for (index, rawLine) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let line = String(rawLine)
            guard let marker = firstMarker(in: line), !disabledMarkers.contains(marker) else { continue }

            let range = NSRange(line.startIndex..., in: line)
            guard let match = detector.matches(in: line, range: range).first,
                  let matchRange = Range(match.range, in: line),
                  var due = match.date
            else { continue }

            let dateText = String(line[matchRange])
            if !mentionsTime(dateText) {
                due = calendar.date(bySettingHour: defaultHour, minute: 0, second: 0, of: due) ?? due
            }

            let title = cleanTitle(line, removing: [matchRange], marker: marker)
            guard !title.isEmpty else { continue }

            proposals.append(Proposal(title: title, dueAt: due, marker: marker, lineIndex: index))
        }
        return proposals
    }

    // MARK: Details

    static func firstMarker(in line: String) -> String? {
        markers.first { marker in
            line.range(of: marker, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    /// Une heure explicite : « 14h », « 14:30 », « 14 h 30 ».
    static func mentionsTime(_ text: String) -> Bool {
        text.range(of: #"\d{1,2}\s*[h:]"#, options: .regularExpression) != nil
    }

    /// Le titre est la ligne debarrassee du marqueur et de la date, plus les
    /// mots de liaison qu'ils laissent derriere eux.
    static func cleanTitle(_ line: String, removing ranges: [Range<String.Index>], marker: String) -> String {
        var text = line
        for range in ranges.sorted(by: { $0.lowerBound > $1.lowerBound }) {
            text.removeSubrange(range)
        }
        if let markerRange = text.range(of: marker, options: [.caseInsensitive, .diacriticInsensitive]) {
            text.removeSubrange(markerRange)
        }
        // « pour », « le », « à » restent souvent seuls apres le retrait.
        let leftovers = ["pour le", "pour", "le ", "la ", "à ", "a ", "-", ":", "·"]
        var cleaned = collapse(text)
        for word in leftovers {
            if cleaned.lowercased().hasSuffix(word.trimmingCharacters(in: .whitespaces)) {
                cleaned = collapse(String(cleaned.dropLast(word.trimmingCharacters(in: .whitespaces).count)))
            }
        }
        return collapse(cleaned)
    }

    private static func collapse(_ text: String) -> String {
        text.split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: " \t-:·,;"))
    }
}
