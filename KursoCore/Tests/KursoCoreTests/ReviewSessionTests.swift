import Testing
@testable import KursoCore

@Suite("Session de revision — §9")
struct ReviewSessionTests {

    func session(cards: Int = 8, gommes: Int = 5, full: Bool = false) -> ReviewSession {
        ReviewSession(cardCount: cards, gommes: gommes, hasFullVersion: full)
    }

    @Test("Le combo monte avec les bonnes reponses")
    func comboRises() {
        var s = session()
        #expect(s.combo == 1)
        s.answer(.knew); s.answer(.knew)
        #expect(s.combo == 2)
        s.answer(.knew); s.answer(.knew)
        #expect(s.combo == 3)
    }

    @Test("Une erreur ramene le combo a un et coute une gomme")
    func mistakeResetsCombo() {
        var s = session()
        s.answer(.knew); s.answer(.knew); s.answer(.knew)
        #expect(s.combo == 2)
        s.answer(.failed)
        #expect(s.combo == 1)
        #expect(s.gommes == 4)
    }

    @Test("« A peu pres » ne casse pas le combo")
    func almostKeepsCombo() {
        var s = session()
        s.answer(.knew); s.answer(.almost)
        #expect(s.combo == 2)
        #expect(s.gommes == 5)
    }

    @Test("L'XP suit le combo du moment")
    func xpFollowsCombo() {
        var s = session()
        #expect(s.answer(.knew) == 15)   // combo ×1 au moment de la reponse
        #expect(s.answer(.knew) == 30)   // combo ×2
    }

    @Test("Au bout des huit cartes, la session est finie")
    func finishes() {
        var s = session(cards: 8)
        for _ in 0..<8 { s.answer(.knew) }
        #expect(s.outcome == .finished)
        #expect(s.unseenCount == 0)
    }

    @Test("A zero gomme la session s'arrete, cartes non vues intactes")
    func stopsWithoutPenalty() {
        // La regle qui compte : on perd le combo, jamais le travail.
        var s = session(cards: 8, gommes: 2)
        s.answer(.failed)
        s.answer(.failed)
        #expect(s.outcome == .outOfGommes)
        #expect(s.gommes == 0)
        #expect(s.unseenCount == 6)
    }

    @Test("Une session terminee n'accepte plus de reponse")
    func ignoresAnswersAfterEnd() {
        var s = session(cards: 1)
        s.answer(.knew)
        #expect(s.outcome == .finished)
        #expect(s.answer(.knew) == 0)
        #expect(s.index == 1)
    }

    @Test("En version complete, les gommes ne descendent pas")
    func fullVersionNeverRunsOut() {
        var s = session(cards: 8, gommes: 5, full: true)
        for _ in 0..<8 { s.answer(.failed) }
        #expect(s.gommes == 5)
        #expect(s.outcome == .finished)
    }

    @Test("Une session sans faute est parfaite")
    func perfectSession() {
        var s = session(cards: 3)
        s.answer(.knew); s.answer(.almost); s.answer(.knew)
        #expect(s.isPerfect)

        var other = session(cards: 2)
        other.answer(.failed); other.answer(.knew)
        #expect(other.isPerfect == false)
    }
}
