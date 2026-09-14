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
    private static let separators = [" : ", " = ", " → ", " -> ", " ≡ "]

    public static func propose(from text: String) -> [Proposal] {
        var found: [Proposal] = []
        for (index, raw) in text.components(separatedBy: .newlines).enumerated() {
            guard found.count < maximum else { break }
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard line.count >= 8, line.count <= 200 else { continue }
            guard let split = separators.compactMap({ line.range(of: $0) }).min(by: {
                $0.lowerBound < $1.lowerBound
            }) else { continue }

            let term = String(line[..<split.lowerBound]).trimmingCharacters(in: .whitespaces)
            let definition = String(line[split.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)

            // Un terme sans definition, ou l'inverse, ne fait pas une carte.
            guard term.count >= 2, definition.count >= 2 else { continue }
            // Une phrase entiere a gauche n'est pas un terme : c'est du cours.
            guard term.split(separator: " ").count <= 8 else { continue }

            found.append(Proposal(id: found.count,
                                  question: question(for: term),
                                  answer: definition,
                                  line: index))
        }
        return found
    }

    /// La question posee autour du terme, sans jamais le reformuler.
    private static func question(for term: String) -> String {
        term.hasSuffix("?") ? term : "\(term) ?"
    }
}
