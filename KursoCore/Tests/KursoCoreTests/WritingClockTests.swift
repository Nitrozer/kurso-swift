import Testing
import Foundation
@testable import KursoCore

@Suite("Temps d'ecriture — §1 : stylet pose, pas temps d'ecran")
struct WritingClockTests {

    let t0 = Date(timeIntervalSince1970: 1_000_000)
    func at(_ offset: TimeInterval) -> Date { t0.addingTimeInterval(offset) }

    @Test("Une page ouverte sans ecrire compte zero")
    func openedButNeverWritten() {
        let clock = WritingClock()
        // Deux heures d'ecran, pas un trait.
        #expect(clock.seconds(now: at(7200)) == 0)
        #expect(clock.isWriting == false)
    }

    @Test("Une periode d'ecriture est comptee")
    func singleSpan() {
        var clock = WritingClock()
        clock.begin(at: at(0))
        clock.end(at: at(12))
        #expect(clock.seconds(now: at(9999)) == 12)
    }

    @Test("Les periodes s'additionnent, les pauses ne comptent pas")
    func multipleSpansIgnorePauses() {
        var clock = WritingClock()
        clock.begin(at: at(0));    clock.end(at: at(10))   // 10 s
        clock.begin(at: at(600));  clock.end(at: at(605))  // 5 s, apres 10 min de pause
        #expect(clock.seconds(now: at(1000)) == 15)
    }

    @Test("La periode en cours est incluse dans le total")
    func inProgressSpanCounts() {
        var clock = WritingClock()
        clock.begin(at: at(0))
        #expect(clock.isWriting)
        #expect(clock.seconds(now: at(7)) == 7)
    }

    @Test("Un second debut sans fin ne double pas le temps")
    func duplicateBeginIsIgnored() {
        var clock = WritingClock()
        clock.begin(at: at(0))
        clock.begin(at: at(5))   // PencilKit peut emettre deux debuts
        clock.end(at: at(10))
        #expect(clock.seconds(now: at(20)) == 10)
    }

    @Test("Une fin sans debut ne change rien")
    func endWithoutBeginIsIgnored() {
        var clock = WritingClock(accumulatedSeconds: 42)
        clock.end(at: at(100))
        #expect(clock.seconds(now: at(200)) == 42)
    }

    @Test("Le total precedent est repris depuis la page")
    func resumesFromStoredValue() {
        var clock = WritingClock(accumulatedSeconds: 300)
        clock.begin(at: at(0))
        clock.end(at: at(60))
        #expect(clock.seconds(now: at(60)) == 360)
    }

    @Test("Un evenement de fin perdu ne gonfle pas le total")
    func lostEndEventIsClamped() {
        var clock = WritingClock()
        clock.begin(at: at(0))
        // L'app est passee en arriere-plan stylet pose : 8 h se sont ecoulees.
        let total = clock.seconds(now: at(8 * 3600))
        #expect(total == Int(WritingClock.maxSpanSeconds))
    }

    @Test("Une horloge systeme qui recule ne retire pas de temps")
    func backwardsClockIsHarmless() {
        var clock = WritingClock(accumulatedSeconds: 50)
        clock.begin(at: at(100))
        clock.end(at: at(40))   // fin avant le debut
        #expect(clock.seconds(now: at(200)) == 50)
    }
}
