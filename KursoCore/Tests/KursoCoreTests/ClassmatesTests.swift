import Testing
import Foundation
@testable import KursoCore

@Suite("Groupes de classe")
struct ClassmatesTests {

    private func group(_ name: String, code: String, members: Int = 3) -> Classmates.Group {
        Classmates.Group(id: name, name: name, joinCode: code, memberCount: members)
    }

    @Test("Un code de groupe se fabrique comme un code ami")
    func codes() {
        let code = Classmates.joinCode(for: "groupe-1")
        #expect(FriendCode.isValid(code))
        #expect(code == Classmates.joinCode(for: "groupe-1"))
        #expect(code != Classmates.joinCode(for: "groupe-2"))
        // Un groupe et un compte de meme identifiant ne tombent pas sur le meme code.
        #expect(code != FriendCode.make(from: "groupe-1"))
    }

    @Test("On ne rejoint pas un groupe ou l'on est deja")
    func alreadyIn() {
        let mine = [group("Terminale B", code: "ABC123")]
        #expect(Classmates.checkJoin(code: "abc-123", groups: mine) == .alreadyIn("Terminale B"))
    }

    @Test("Trois groupes au maximum")
    func tooMany() {
        let three = [group("A", code: "AAA111"), group("B", code: "BBB222"), group("C", code: "CCC333")]
        #expect(Classmates.checkJoin(code: "DDD444", groups: three) == .tooManyGroups)
        #expect(Classmates.checkCreate(name: "TD info", groups: three) == .tooManyGroups)
        #expect(Classmates.maxGroups == 3)
    }

    @Test("Un code mal tape est refuse avant le reseau")
    func malformed() {
        #expect(Classmates.checkJoin(code: "AB", groups: []) == .malformed)
    }

    @Test("Un groupe sans nom ne se cree pas")
    func nameless() {
        #expect(Classmates.checkCreate(name: "   ", groups: []) == .namelessGroup)
        #expect(Classmates.checkCreate(name: "Terminale B", groups: []) == nil)
    }

    @Test("Rejoindre un groupe inconnu passe : c'est au serveur de repondre")
    func unknownIsServerSide() {
        #expect(Classmates.checkJoin(code: "QRS456", groups: []) == nil)
    }

    @Test("Le sous-titre se lit au singulier quand on est seul")
    func subtitles() {
        #expect(Classmates.subtitle(group("A", code: "AAA111", members: 1)) == "Toi seul pour l'instant")
        #expect(Classmates.subtitle(group("A", code: "AAA111", members: 2)) == "Toi et une autre personne")
        #expect(Classmates.subtitle(group("A", code: "AAA111", members: 24)) == "24 personnes")
    }

    @Test("Chaque refus porte sa phrase")
    func everyRefusalSpeaks() {
        let all: [Classmates.Refusal] = [.malformed, .alreadyIn("A"), .full("A"), .tooManyGroups, .namelessGroup]
        for refusal in all { #expect(!refusal.sentence.isEmpty) }
    }
}
