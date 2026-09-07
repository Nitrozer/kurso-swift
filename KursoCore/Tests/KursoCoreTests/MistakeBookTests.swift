import Testing
@testable import KursoCore

@Suite("Carnet des ratés — §2")
struct MistakeBookTests {

    @Test("Une carte entre au carnet a deux echecs")
    func entryThreshold() {
        #expect(MistakeBook.contains(lapses: 1) == false)
        #expect(MistakeBook.contains(lapses: 2))
        #expect(MistakeBook.contains(lapses: 7))
    }

    @Test("Le carnet devient un boss a dix cartes")
    func bossThreshold() {
        #expect(MistakeBook.isBoss(count: 9) == false)
        #expect(MistakeBook.isBoss(count: 10))
    }

    @Test("Vider le carnet en entier, sans faute, le solde")
    func clearedEntirely() {
        let reward = MistakeBook.evaluate(bookSize: 4, answered: 4, failures: 0)
        #expect(reward.clearedEntirely)
    }

    @Test("Une seule faute laisse le carnet ouvert")
    func oneFailureKeepsItOpen() {
        // Sinon la recompense se donnerait a force d'essais, pas de maitrise.
        let reward = MistakeBook.evaluate(bookSize: 4, answered: 4, failures: 1)
        #expect(reward.clearedEntirely == false)
    }

    @Test("Une session interrompue ne solde rien")
    func partialSessionClearsNothing() {
        let reward = MistakeBook.evaluate(bookSize: 6, answered: 3, failures: 0)
        #expect(reward.clearedEntirely == false)
    }

    @Test("La fiche or n'arrive que pour un boss")
    func goldOnlyForBoss() {
        #expect(MistakeBook.evaluate(bookSize: 4, answered: 4, failures: 0).goldCard == false)
        #expect(MistakeBook.evaluate(bookSize: 10, answered: 10, failures: 0).goldCard)
    }

    @Test("Un carnet vide ne recompense rien")
    func emptyBook() {
        #expect(MistakeBook.evaluate(bookSize: 0, answered: 0, failures: 0).clearedEntirely == false)
    }
}
