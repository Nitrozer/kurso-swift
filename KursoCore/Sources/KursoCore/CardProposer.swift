import Foundation

/// Trois cartes tirees de ce qu'on vient d'ecrire (§11, etape 4).
///
/// Aucune generation : on ne REDIGE rien, on decoupe. Une ligne qui pose une
/// definition devient une question et sa reponse, mot pour mot. Le §12
/// interdit de generer du contenu, et une carte qu'on n'a pas ecrite ne
/// s'apprend pas.
///
/// Jamais plus de trois : au-dela, personne ne trie et tout finit garde.
public enum CardProposer {

    public static let maximum = 3

    public struct Proposal: Equatable, Sendable, Identifiable {
        public let id: Int
        public let question: String
        public let answer: String
        /// La ligne d'ou elle vient, pour pouvoir la retrouver.
        public let line: Int

        public init(id: Int, question: String, answer: String, line: Int) {
            self.id = id
            self.question = question
            self.answer = answer
            self.line = line
        }
    }

    /// Ce qui separe un terme de sa definition, dans une prise de notes.
    ///
    /// Les espaces autour ne sont PAS exiges. C'est le piege qui rendait la
    /// proposition muette : la reconnaissance d'ecriture ne garantit pas
    /// l'espace avant un deux-points, et « PID : reglage » comme
    /// « PID: reglage » sont la meme note. Seules les formes espacees
    /// marchaient, donc presque rien ne marchait.
    ///
    /// Les plus longs d'abord : sans cela, la fleche « -> » serait coupee sur
    /// son trait d'union.
    private static let separators = ["->", "→", "≡", "—", "–", ":", "="]

    /// Le trait d'union simple n'est admis qu'entoure d'espaces, sinon
    /// « porte-cles » deviendrait une definition.
    private static let spacedOnly = "-"

    public static func propose(from text: String) -> [Proposal] {
        var found: [Proposal] = []
        for (index, raw) in text.components(separatedBy: .newlines).enumerated() {
            guard found.count < maximum else { break }
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard line.count >= 8, line.count <= 200 else { continue }
            guard let cut = split(line) else { continue }

            // Un terme sans definition, ou l'inverse, ne fait pas une carte.
            guard cut.term.count >= 2, cut.definition.count >= 2 else { continue }
            // Une phrase entiere a gauche n'est pas un terme : c'est du cours.
            guard cut.term.split(separator: " ").count <= 8 else { continue }

            found.append(Proposal(id: found.count,
                                  question: question(for: cut.term),
                                  answer: cut.definition,
                                  line: index))
        }
        return found
    }

    /// Le premier separateur acceptable de la ligne, et ce qu'il decoupe.
    private static func split(_ line: String) -> (term: String, definition: String)? {
        var index = line.startIndex
        while index < line.endIndex {
            for separator in separators where line[index...].hasPrefix(separator) {
                let after = line.index(index, offsetBy: separator.count)
                // « 14:30 amphi B » est une heure, pas une definition.
                if separator == ":", isBetweenDigits(line, before: index, after: after) { continue }
                return cut(line, at: index, after: after)
            }
            if line[index...].hasPrefix(spacedOnly),
               isSpaced(line, before: index, after: line.index(after: index)) {
                return cut(line, at: index, after: line.index(after: index))
            }
            index = line.index(after: index)
        }
        return nil
    }

    private static func cut(_ line: String, at start: String.Index,
                            after end: String.Index) -> (term: String, definition: String) {
        (String(line[..<start]).trimmingCharacters(in: .whitespaces),
         String(line[end...]).trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func isBetweenDigits(_ line: String, before: String.Index, after: String.Index) -> Bool {
        guard before > line.startIndex, after < line.endIndex else { return false }
        return line[line.index(before: before)].isNumber && line[after].isNumber
    }

    private static func isSpaced(_ line: String, before: String.Index, after: String.Index) -> Bool {
        guard before > line.startIndex, after < line.endIndex else { return false }
        return line[line.index(before: before)].isWhitespace && line[after].isWhitespace
    }

    /// La question posee autour du terme, sans jamais le reformuler.
    private static func question(for term: String) -> String {
        term.hasSuffix("?") ? term : "\(term) ?"
    }
}
