import Testing
@testable import KursoCore

@Suite("Échelle de combo")
struct ComboScaleTests {

    @Test("Les crans suivent les seuils du jeu")
    func matchesGameValues() {
        // Si GameValues bouge, l'echelle affichee doit bouger avec.
        for step in ComboScale.steps {
            guard let streak = step.streak else { continue }
            #expect(GameValues.combo(forStreak: streak) == step.multiplier)
        }
    }

    @Test("Le cran atteint suit la serie")
    func stepForStreak() {
        #expect(ComboScale.step(forStreak: 0).multiplier == 1)
        #expect(ComboScale.step(forStreak: 2).multiplier == 2)
        #expect(ComboScale.step(forStreak: 5).multiplier == 3)
        #expect(ComboScale.step(forStreak: 12).multiplier == 4)
    }

    @Test("Le cran final ne s'obtient pas en comptant")
    func perfectStepHasNoStreak() {
        #expect(ComboScale.steps.last?.streak == nil)
        #expect(ComboScale.steps.last?.multiplier == GameValues.perfectPageCombo)
    }

    @Test("Le compte restant s'accorde")
    func remaining() {
        #expect(ComboScale.remaining(answered: 4, total: 8) == "4 cartes restantes · 3 min")
        #expect(ComboScale.remaining(answered: 7, total: 8) == "1 carte restante · 1 min")
        #expect(ComboScale.remaining(answered: 8, total: 8) == "Dernière carte")
    }
}
