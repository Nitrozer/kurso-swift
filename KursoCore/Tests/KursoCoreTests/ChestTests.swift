import Testing
@testable import KursoCore

@Suite("Coffres — §9")
struct ChestTests {

    @Test("Pas de coffre au niveau un")
    func noneAtFirstLevel() {
        #expect(Chest.shavings(forLevel: 1) == 0)
        #expect(Chest.cover(forLevel: 1, owned: []) == nil)
    }

    @Test("Les copeaux montent avec le niveau, sans s'emballer")
    func shavingsGrow() {
        #expect(Chest.shavings(forLevel: 2) == 60)
        #expect(Chest.shavings(forLevel: 3) == 80)
        #expect(Chest.shavings(forLevel: 10) == 220)
    }

    @Test("Un coffre sur trois apporte une couverture")
    func coverEveryThirdLevel() {
        #expect(Chest.cover(forLevel: 3, owned: []) != nil)
        #expect(Chest.cover(forLevel: 4, owned: []) == nil)
        #expect(Chest.cover(forLevel: 6, owned: []) != nil)
    }

    @Test("Aucune couverture en double")
    func neverDuplicates() {
        let all = Set(Shop.Cover.allCases.filter { $0.price > 0 }.map(\.rawValue))
        #expect(Chest.cover(forLevel: 9, owned: all) == nil)
    }

    @Test("Le meme niveau donne toujours la meme chose")
    func deterministic() {
        // Rien n'est tire au sort : relancer l'app ne change pas le contenu.
        #expect(Chest.shavings(forLevel: 5) == Chest.shavings(forLevel: 5))
        #expect(Chest.cover(forLevel: 6, owned: []) == Chest.cover(forLevel: 6, owned: []))
    }

    @Test("Monter de deux niveaux d'un coup donne deux coffres")
    func catchesUp() {
        #expect(Chest.pending(currentLevel: 4, lastOpened: 2) == [3, 4])
    }

    @Test("Un gel de serie par coffre")
    func oneFreezePerChest() {
        #expect(Chest.freezes(inReserve: 0, chests: 1) == 1)
        #expect(Chest.freezes(inReserve: 0, chests: 2) == 2)
    }

    @Test("Jamais plus de deux gels en reserve")
    func freezesCapped() {
        // Le §9 plafonne la reserve a deux : six coffres n'en donnent pas six.
        #expect(Chest.freezes(inReserve: 0, chests: 6) == 2)
        #expect(Chest.freezes(inReserve: 1, chests: 6) == 1)
        #expect(Chest.freezes(inReserve: 2, chests: 6) == 0)
    }

    @Test("Rien a ouvrir quand tout l'a ete")
    func nothingPending() {
        #expect(Chest.pending(currentLevel: 3, lastOpened: 3).isEmpty)
        #expect(Chest.pending(currentLevel: 1, lastOpened: 1).isEmpty)
    }
}
