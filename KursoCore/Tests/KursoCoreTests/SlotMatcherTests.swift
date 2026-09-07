import Testing
import Foundation
@testable import KursoCore

@Suite("Rattachement page ↔ creneau — §6")
struct SlotMatcherTests {

    let base = Date(timeIntervalSince1970: 1_800_000_000)
    func at(_ minutes: Double) -> Date { base.addingTimeInterval(minutes * 60) }

    /// Un cours de deux heures. Identifiant fixe : une propriete calculee en
    /// fabriquerait un nouveau a chaque acces, et la comparaison echouerait.
    let course = SlotMatcher.Slot(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000C0")!,
        start: Date(timeIntervalSince1970: 1_800_000_000),
        end: Date(timeIntervalSince1970: 1_800_000_000 + 7200)
    )

    @Test("Pendant le cours, la page se rattache")
    func duringCourse() {
        #expect(SlotMatcher.slotInProgress(at: at(30), among: [course]) == course)
    }

    @Test("Quinze minutes avant le debut, ca compte encore")
    func justBefore() {
        // On arrive rarement pile a l'heure.
        #expect(SlotMatcher.slotInProgress(at: at(-14), among: [course]) == course)
    }

    @Test("Quinze minutes apres la fin, ca compte encore")
    func justAfter() {
        // On finit souvent d'ecrire apres la sonnerie.
        #expect(SlotMatcher.slotInProgress(at: at(134), among: [course]) == course)
    }

    @Test("Au-dela de la tolerance, plus rien")
    func outsideTolerance() {
        #expect(SlotMatcher.slotInProgress(at: at(-16), among: [course]) == nil)
        #expect(SlotMatcher.slotInProgress(at: at(136), among: [course]) == nil)
    }

    @Test("Sans creneau, la page reste non rattachee")
    func noSlots() {
        #expect(SlotMatcher.slotInProgress(at: at(30), among: []) == nil)
    }

    @Test("Entre deux cours, on retient le plus proche")
    func overlappingPicksNearest() {
        // Deux creneaux qui se chevauchent : on est assis dans celui dont on
        // occupe le milieu.
        let morning = SlotMatcher.Slot(id: UUID(), start: at(0),   end: at(120))
        let noon    = SlotMatcher.Slot(id: UUID(), start: at(110), end: at(230))
        #expect(SlotMatcher.slotInProgress(at: at(115), among: [morning, noon]) == morning)
        #expect(SlotMatcher.slotInProgress(at: at(180), among: [morning, noon]) == noon)
    }

    @Test("Les bornes exactes sont incluses")
    func exactBounds() {
        #expect(SlotMatcher.slotInProgress(at: at(0), among: [course]) == course)
        #expect(SlotMatcher.slotInProgress(at: at(120), among: [course]) == course)
    }
}
