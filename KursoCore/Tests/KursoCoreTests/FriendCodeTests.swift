import Testing
import Foundation
@testable import KursoCore

@Suite("Code ami")
struct FriendCodeTests {

    @Test("Le meme compte rend toujours le meme code")
    func deterministic() {
        // Le piege serait `hashValue`, sale a chaque lancement : le code aurait
        // change a chaque ouverture de l'application.
        let once = FriendCode.make(from: "6f1c2a80-0000-4000-8000-000000000001")
        let twice = FriendCode.make(from: "6f1c2a80-0000-4000-8000-000000000001")
        #expect(once == twice)
    }

    @Test("Six signes, tous lisibles")
    func shapeAndAlphabet() {
        let code = FriendCode.make(from: "thomas")
        #expect(code.count == FriendCode.length)
        #expect(code.allSatisfy(FriendCode.alphabet.contains))
        #expect(!code.contains("I"))
        #expect(!code.contains("L"))
        #expect(!code.contains("O"))
        #expect(!code.contains("U"))
    }

    @Test("Deux comptes ne partagent pas leur code")
    func distinct() {
        let codes = Set((0..<500).map { FriendCode.make(from: "compte-\($0)") })
        #expect(codes.count == 500)
    }

    @Test("Le sel donne une autre chance quand le serveur refuse")
    func saltChangesEverything() {
        #expect(FriendCode.make(from: "thomas", salt: 0) != FriendCode.make(from: "thomas", salt: 1))
    }

    @Test("Le tiret n'existe qu'a l'ecran")
    func formatting() {
        #expect(FriendCode.format("ABC123") == "ABC-123")
        #expect(FriendCode.format("abc-123") == "ABC-123")
    }

    @Test("Les jumeaux se ramenent sur le signe retenu")
    func normalisation() {
        #expect(FriendCode.normalise("abc-123") == "ABC123")
        #expect(FriendCode.normalise("O0 Il") == "0011")
        #expect(FriendCode.normalise("A B-C_1.2 3") == "ABC123")
    }

    @Test("Un code mal tape est refuse")
    func validity() {
        #expect(FriendCode.isValid("ABC123"))
        #expect(FriendCode.isValid("abc-123"))
        // Les jumeaux dictes restent acceptes : c'est tout l'interet.
        #expect(FriendCode.isValid("OBC1I3"))
        #expect(!FriendCode.isValid("ABC12"))
        #expect(!FriendCode.isValid("ABC1234"))
        #expect(!FriendCode.isValid("ABC12U"))
        #expect(!FriendCode.isValid(""))
    }
}
