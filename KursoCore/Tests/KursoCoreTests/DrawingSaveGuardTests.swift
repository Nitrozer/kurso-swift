import Testing
@testable import KursoCore

@Suite("Ecrasement d'un trace")
struct DrawingSaveGuardTests {
    @Test("Un geste fait foi, meme pour vider la page")
    func gestureAlwaysWins() {
        #expect(DrawingSaveGuard.shouldWrite(incomingStrokes: 0, storedStrokes: 12, origin: .gesture))
        #expect(DrawingSaveGuard.shouldWrite(incomingStrokes: 5, storedStrokes: 0, origin: .gesture))
    }

    @Test("Fermer une page ne l'efface jamais")
    func teardownNeverEmpties() {
        #expect(!DrawingSaveGuard.shouldWrite(incomingStrokes: 0, storedStrokes: 12, origin: .teardown))
    }

    @Test("Fermer une page enregistre bien ce qu'elle contient")
    func teardownStillSaves() {
        #expect(DrawingSaveGuard.shouldWrite(incomingStrokes: 12, storedStrokes: 3, origin: .teardown))
        #expect(DrawingSaveGuard.shouldWrite(incomingStrokes: 4, storedStrokes: 4, origin: .teardown))
    }

    @Test("Une page vide qui reste vide ne pose pas de probleme")
    func emptyStaysEmpty() {
        #expect(DrawingSaveGuard.shouldWrite(incomingStrokes: 0, storedStrokes: 0, origin: .teardown))
    }
}
