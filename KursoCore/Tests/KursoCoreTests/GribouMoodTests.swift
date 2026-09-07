import Testing
@testable import KursoCore

@Suite("Gribou — humeurs et retenue")
struct GribouMoodTests {

    @Test("Il ne bouge jamais pendant qu'on écrit")
    func silentWhileWriting() {
        // La règle qui protège le registre outil : une mascotte qui gigote
        // pendant une prise de notes en cours est insupportable.
        let context = Gribou.Context(isPencilDown: true, isInClass: true,
                                     hasOverdueAssignment: true, streak: 10, hour: 23)
        #expect(Gribou.mood(for: context) == nil)
    }

    @Test("Un devoir en retard passe avant tout le reste")
    func overdueWins() {
        let context = Gribou.Context(isInClass: true, hasOverdueAssignment: true, streak: 10, hour: 23)
        #expect(Gribou.mood(for: context) == .inquiet)
    }

    @Test("En cours, il est concentré")
    func inClass() {
        #expect(Gribou.mood(for: .init(isInClass: true, streak: 10)) == .concentre)
    }

    @Test("Passé 23 h, il dort")
    func sleepy() {
        #expect(Gribou.mood(for: .init(streak: 10, hour: 23)) == .endormi)
        #expect(Gribou.mood(for: .init(streak: 10, hour: 3)) == .endormi)
    }

    @Test("Une série tenue le rend fier")
    func proud() {
        #expect(Gribou.mood(for: .init(streak: 3, hour: 14)) == .fier)
        #expect(Gribou.mood(for: .init(streak: 2, hour: 14)) == .idle)
    }

    @Test("Sans rien de particulier, il est au repos")
    func idle() {
        #expect(Gribou.mood(for: .init()) == .idle)
    }

    @Test("Trois apparitions par session au maximum")
    func appearanceBudget() {
        #expect(Gribou.canAppear(appearancesSoFar: 2))
        #expect(Gribou.canAppear(appearancesSoFar: 3) == false)
    }

    @Test("Chaque humeur nomme un clip existant")
    func everyMoodHasAClip() {
        for mood in GribouMood.allCases {
            #expect(mood.clipName.hasPrefix("Gribou_"))
        }
    }
}
