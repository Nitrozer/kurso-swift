import Testing
import Foundation
@testable import KursoCore

@Suite("Cartes proposees en fin de cours")
struct CardProposerTests {

    @Test("Une definition devient une carte, mot pour mot")
    func definitionBecomesCard() throws {
        let found = CardProposer.propose(from: "Tas binaire : arbre presque complet")
        let first = try #require(found.first)
        #expect(first.question == "Tas binaire ?")
        #expect(first.answer == "arbre presque complet")
    }

    @Test("Les autres separateurs marchent aussi")
    func otherSeparators() {
        #expect(CardProposer.propose(from: "Hauteur = ⌊log₂ n⌋").first?.answer == "⌊log₂ n⌋")
        #expect(CardProposer.propose(from: "Insertion → O(log n)").first?.answer == "O(log n)")
    }

    @Test("Jamais plus de trois")
    func neverMoreThanThree() {
        let text = (1...10).map { "Terme \($0) : definition \($0)" }.joined(separator: "\n")
        #expect(CardProposer.propose(from: text).count == 3)
    }

    @Test("Une phrase de cours n'est pas un terme")
    func prosePassesThrough() {
        let text = "On remonte l'element tant que le parent est plus grand que l'enfant : voila"
        #expect(CardProposer.propose(from: text).isEmpty)
    }

    @Test("Une ligne trop courte ou vide ne donne rien")
    func tooShort() {
        #expect(CardProposer.propose(from: "a : b").isEmpty)
        #expect(CardProposer.propose(from: "").isEmpty)
        #expect(CardProposer.propose(from: "Terme : ").isEmpty)
    }

    @Test("La ligne d'origine est retenue")
    func keepsSourceLine() {
        let text = "titre\n\nTas binaire : arbre complet"
        #expect(CardProposer.propose(from: text).first?.line == 2)
    }

    @Test("Un terme deja interrogatif n'est pas double")
    func noDoubleQuestionMark() {
        #expect(CardProposer.propose(from: "Pourquoi O(n) ? : somme des hauteurs").first?.question == "Pourquoi O(n) ?")
    }
}
