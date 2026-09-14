import Testing
import Foundation
@testable import KursoCore

@Suite("Mode partiel — §9")
struct ExamModeTests {
    private let cal = Calendar(identifier: .gregorian)
    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private func inDays(_ n: Int) -> Date {
        Calendar(identifier: .gregorian).date(byAdding: .day, value: n, to: Date(timeIntervalSince1970: 1_700_000_000))!
    }

    @Test("Sans examen prevu, pas de mode partiel")
    func noExamNoMode() {
        #expect(!ExamMode.isActive(examDate: nil, now: now, calendar: cal))
    }

    @Test("Le mode s'ouvre a quatorze jours")
    func opensAtFourteenDays() {
        #expect(ExamMode.isActive(examDate: inDays(14), now: now, calendar: cal))
        #expect(!ExamMode.isActive(examDate: inDays(15), now: now, calendar: cal))
    }

    @Test("Vingt et un jours apres un semestre difficile")
    func widerAfterRedPages() {
        #expect(ExamMode.isActive(examDate: inDays(20), now: now, hadRedPages: true, calendar: cal))
        #expect(!ExamMode.isActive(examDate: inDays(22), now: now, hadRedPages: true, calendar: cal))
    }

    @Test("Un examen passe ne rouvre pas le mode")
    func pastExamCloses() {
        #expect(!ExamMode.isActive(examDate: inDays(-1), now: now, calendar: cal))
    }

    @Test("Les sessions passent a vingt cartes")
    func longerSessions() {
        #expect(ExamMode.sessionSize(isExamMode: true, ordinary: 8) == 20)
        #expect(ExamMode.sessionSize(isExamMode: false, ordinary: 8) == 8)
    }

    @Test("Une carte sur trois se tire a l'envers")
    func oneInThreeReversed() {
        let flags = (0..<6).map { ExamMode.isReversed(index: $0, isExamMode: true) }
        #expect(flags == [false, false, true, false, false, true])
    }

    @Test("Hors mode partiel, rien ne s'inverse")
    func neverReversedOutside() {
        #expect((0..<6).allSatisfy { !ExamMode.isReversed(index: $0, isExamMode: false) })
    }

    @Test("Le jeu se met en veille")
    func gameGoesQuiet() {
        #expect(!ExamMode.showsGame(isExamMode: true))
        #expect(ExamMode.showsGame(isExamMode: false))
    }
}
