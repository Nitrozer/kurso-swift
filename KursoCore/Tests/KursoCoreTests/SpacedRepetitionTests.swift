import Testing
import Foundation
@testable import KursoCore

@Suite("Repetition espacee — §2")
struct SpacedRepetitionTests {

    typealias SR = SpacedRepetition

    @Test("Trois « je savais » donnent 1 j, 3 j, puis × ease")
    func theDocumentedSequence() {
        // Le premier controle a faire d'apres le paquet de passation :
        // « si les intervalles ne correspondent pas au §2, tout le reste est faux ».
        var state = SR.State()
        state = SR.apply(.knew, to: state)
        #expect(state.interval == 1)

        state = SR.apply(.knew, to: state)
        #expect(state.interval == 3)

        let easeBefore = state.ease
        state = SR.apply(.knew, to: state)
        #expect(state.ease == min(SR.maxEase, easeBefore + 0.10))
        #expect(state.interval == Int((3.0 * state.ease).rounded()))
    }

    @Test("L'aisance de depart vaut 2,3")
    func initialEase() {
        #expect(SR.State().ease == 2.3)
    }

    @Test("« Je savais » monte l'aisance sans depasser 2,8")
    func easeCeiling() {
        var state = SR.State(interval: 10, ease: 2.75)
        state = SR.apply(.knew, to: state)
        #expect(state.ease == 2.8)
    }

    @Test("« Je sechais » descend l'aisance sans passer sous 1,3")
    func easeFloor() {
        var state = SR.State(interval: 10, ease: 1.4)
        state = SR.apply(.failed, to: state)
        #expect(state.ease == 1.3)
    }

    @Test("« Je sechais » ramene l'intervalle a 1 et compte un echec")
    func failureResets() {
        let state = SR.apply(.failed, to: SR.State(interval: 40, ease: 2.5))
        #expect(state.interval == 1)
        #expect(state.lapses == 1)
    }

    @Test("« A peu pres » avance moins vite et baisse l'aisance de 0,05")
    func almost() {
        let state = SR.apply(.almost, to: SR.State(interval: 10, ease: 2.3))
        #expect(state.ease == 2.25)
        #expect(state.interval == 12)   // round(10 × 1,2)
    }

    @Test("L'intervalle est plafonne a 180 jours")
    func intervalCeiling() {
        let state = SR.apply(.knew, to: SR.State(interval: 150, ease: 2.8))
        #expect(state.interval == 180)
    }

    @Test("Deux echecs font entrer au carnet des rates")
    func mistakeBook() {
        #expect(SR.isInMistakeBook(SR.State(lapses: 1)) == false)
        #expect(SR.isInMistakeBook(SR.State(lapses: 2)))
    }

    @Test("L'echeance tombe a 04:00")
    func dueAtFourInTheMorning() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let due = SR.dueDate(from: SR.State(interval: 3), now: now, calendar: calendar)
        #expect(calendar.component(.hour, from: due) == 4)
        #expect(calendar.dateComponents([.day], from: now, to: due).day == 2)
    }
}
