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

    @Test("Les espaces autour du separateur ne sont pas exiges")
    func spacingIsNotRequired() {
        // C'est le defaut qui rendait la proposition muette : la
        // reconnaissance d'ecriture ne garantit pas l'espace avant un
        // deux-points, et seules les formes espacees etaient reconnues.
        let forms = [
            "Correcteur PID : annule l'erreur statique",
            "Correcteur PID: annule l'erreur statique",
            "Correcteur PID :annule l'erreur statique",
            "Correcteur PID=annule l'erreur statique",
            "Correcteur PID — annule l'erreur statique",
            "Correcteur PID - annule l'erreur statique",
        ]
        for form in forms {
            let found = CardProposer.propose(from: form)
            #expect(found.count == 1, "rien trouve dans « \(form) »")
            #expect(found.first?.question == "Correcteur PID ?")
            #expect(found.first?.answer == "annule l'erreur statique")
        }
    }

    @Test("Une heure n'est pas une definition")
    func timeIsNotACard() {
        // « 14:30 amphi B » se lit tous les jours dans un cahier de cours.
        #expect(CardProposer.propose(from: "Cours 14:30 amphi B").isEmpty)
        // Mais un deux-points qui suit vraiment un terme reste une carte.
        #expect(CardProposer.propose(from: "Periode T: 14 jours").first?.answer == "14 jours")
    }

    @Test("Un mot compose reste un mot")
    func hyphenatedWordIsNotASplit() {
        // Sans l'exigence d'espaces autour du trait d'union, « porte-cles »
        // serait devenu une definition.
        #expect(CardProposer.propose(from: "porte-cles du trousseau").isEmpty)
    }

    @Test("Un terme deja interrogatif n'est pas double")
    func noDoubleQuestionMark() {
        #expect(CardProposer.propose(from: "Pourquoi O(n) ? : somme des hauteurs").first?.question == "Pourquoi O(n) ?")
    }
}
