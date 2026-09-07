import Testing
import Foundation
@testable import KursoCore

@Suite("Valeurs de jeu — §9")
struct GameValuesTests {

    typealias G = GameValues

    @Test("Le combo suit les paliers du document")
    func comboLadder() {
        #expect(G.combo(forStreak: 0) == 1)
        #expect(G.combo(forStreak: 1) == 1)
        #expect(G.combo(forStreak: 2) == 2)
        #expect(G.combo(forStreak: 3) == 2)
        #expect(G.combo(forStreak: 4) == 3)
        #expect(G.combo(forStreak: 6) == 3)
        #expect(G.combo(forStreak: 7) == 4)
        #expect(G.combo(forStreak: 40) == 4)
    }

    @Test("Une carte juste rapporte 15 × combo, double au sprint")
    func cardXP() {
        #expect(G.xpForCard(combo: 1) == 15)
        #expect(G.xpForCard(combo: 3) == 45)
        #expect(G.xpForCard(combo: 3, isSprint: true) == 90)
    }

    @Test("Les niveaux suivent le seuil cumule de 50")
    func levels() {
        #expect(G.level(forTotalXP: 0) == 1)
        #expect(G.level(forTotalXP: 49) == 1)
        #expect(G.level(forTotalXP: 50) == 2)
        #expect(G.level(forTotalXP: 100) == 3)
    }

    @Test("Une erreur coute une gomme, jamais en version complete")
    func gommeCost() {
        #expect(G.gommesAfterMistake(3, hasFullVersion: false) == 2)
        #expect(G.gommesAfterMistake(3, hasFullVersion: true) == 3)
        // Le compteur ne passe jamais sous zero.
        #expect(G.gommesAfterMistake(0, hasFullVersion: false) == 0)
    }

    @Test("Les gommes se regenerent d'une toutes les quatre heures")
    func gommeRegen() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(G.regenerate(remaining: 2, since: start, now: start.addingTimeInterval(3600)).remaining == 2)
        #expect(G.regenerate(remaining: 2, since: start, now: start.addingTimeInterval(4 * 3600)).remaining == 3)
        #expect(G.regenerate(remaining: 2, since: start, now: start.addingTimeInterval(9 * 3600)).remaining == 4)
    }

    @Test("La regeneration est plafonnee a cinq")
    func gommeCeiling() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(G.regenerate(remaining: 4, since: start, now: start.addingTimeInterval(100 * 3600)).remaining == 5)
    }

    @Test("Le temps deja converti n'est pas recompte")
    func regenDoesNotDoubleCount() {
        // Sans avancer la date de reference, les gommes remonteraient seules a
        // chaque affichage.
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let first = G.regenerate(remaining: 1, since: start, now: start.addingTimeInterval(5 * 3600))
        #expect(first.remaining == 2)
        let second = G.regenerate(remaining: first.remaining, since: first.lastRegen,
                                  now: start.addingTimeInterval(6 * 3600))
        #expect(second.remaining == 2)
    }

    @Test("La mine s'use en dix heures d'ecriture")
    func mineWear() {
        #expect(G.mineWear(writingSecondsSinceLevel: 0) == 0)
        #expect(G.mineWear(writingSecondsSinceLevel: 18_000) == 0.5)
        #expect(G.mineWear(writingSecondsSinceLevel: 36_000) == 1)
        #expect(G.mineWear(writingSecondsSinceLevel: 99_999) == 1)
    }

    @Test("Le mode partiel s'active a quatorze jours, vingt-et-un apres un mauvais semestre")
    func examMode() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        func exam(inDays days: Double) -> Date { now.addingTimeInterval(days * 86_400) }

        #expect(G.isExamMode(examDate: exam(inDays: 20), now: now) == false)
        #expect(G.isExamMode(examDate: exam(inDays: 13), now: now))
        #expect(G.isExamMode(examDate: exam(inDays: 20), now: now, previousSeasonHadRedPages: true))
        // Un examen passe ne declenche rien.
        #expect(G.isExamMode(examDate: exam(inDays: -1), now: now) == false)
        #expect(G.isExamMode(examDate: nil, now: now) == false)
    }
}
