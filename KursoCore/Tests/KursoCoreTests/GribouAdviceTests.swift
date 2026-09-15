import Testing
@testable import KursoCore

@Suite("Ce que Gribou dit — §12")
struct GribouAdviceTests {

    private func tip(_ id: String, _ kind: GribouAdvice.Kind) -> GribouAdvice.Tip {
        .init(id: id, kind: kind, text: id)
    }

    @Test("Ce qui demande une action passe avant tout")
    func actionWins() {
        let chosen = GribouAdvice.choose(
            from: [tip("bravo", .cheer), tip("gomme", .mechanic),
                   tip("pages", .action), tip("rates", .debrief)],
            spent: 0)
        #expect(chosen?.id == "pages")
    }

    @Test("Sinon, le commentaire de ce qui vient de se passer")
    func debriefNext() {
        let chosen = GribouAdvice.choose(
            from: [tip("bravo", .cheer), tip("gomme", .mechanic), tip("rates", .debrief)],
            spent: 0)
        #expect(chosen?.id == "rates")
    }

    @Test("A registre egal, l'ecran garde son ordre")
    func stableOrder() {
        let chosen = GribouAdvice.choose(
            from: [tip("premier", .action), tip("second", .action)], spent: 0)
        #expect(chosen?.id == "premier")
    }

    @Test("Le plafond du §12 est tenu")
    func budgetHolds() {
        let candidates = [tip("pages", .action)]
        #expect(GribouAdvice.choose(from: candidates, spent: 2)?.id == "pages")
        // Trois apparitions consommees : il se tait, meme pour une action.
        #expect(GribouAdvice.choose(from: candidates, spent: 3) == nil)
        #expect(GribouAdvice.choose(from: candidates, spent: 9) == nil)
    }

    @Test("Une mecanique ne s'explique qu'une fois")
    func mechanicOnce() {
        let candidates = [tip("gomme", .mechanic)]
        #expect(GribouAdvice.choose(from: candidates, spent: 0)?.id == "gomme")
        #expect(GribouAdvice.choose(from: candidates, spent: 0, seen: ["gomme"]) == nil)
    }

    @Test("Un encouragement, lui, peut revenir")
    func cheerRepeats() {
        let candidates = [tip("bravo", .cheer)]
        #expect(GribouAdvice.choose(from: candidates, spent: 0, seen: ["bravo"])?.id == "bravo")
    }

    @Test("Rien a dire : il se tait")
    func silence() {
        #expect(GribouAdvice.choose(from: [], spent: 0) == nil)
    }

    @Test("Le budget restant se lit")
    func remaining() {
        #expect(GribouAdvice.remaining(spent: 0) == 3)
        #expect(GribouAdvice.remaining(spent: 3) == 0)
        #expect(GribouAdvice.remaining(spent: 5) == 0)
    }
}
