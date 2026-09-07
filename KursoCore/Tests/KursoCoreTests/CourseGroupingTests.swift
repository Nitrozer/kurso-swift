import Testing
import Foundation
@testable import KursoCore

@Suite("Regroupement en matieres — §6")
struct CourseGroupingTests {

    func event(_ summary: String, uid: String = UUID().uuidString) -> ICSEvent {
        ICSEvent(uid: uid, summary: summary, location: nil,
                 start: Date(), end: Date(), recurrenceRule: nil)
    }

    @Test("Deux intitules identiques font une seule matiere")
    func identical() {
        let groups = CourseGrouping.group([event("Analyse III"), event("Analyse III")])
        #expect(groups.count == 1)
        #expect(groups[0].occurrences == 2)
    }

    @Test("La casse et les accents ne separent pas")
    func caseAndAccents() {
        let groups = CourseGrouping.group([event("Algorithmique avancée"), event("ALGORITHMIQUE AVANCEE")])
        #expect(groups.count == 1)
    }

    @Test("Deux matieres differentes restent separees")
    func distinctSubjects() {
        let groups = CourseGrouping.group([event("Analyse III"), event("Physique quantique")])
        #expect(groups.count == 2)
    }

    @Test("Le nom propose est le plus frequent")
    func picksMostFrequentName() {
        let groups = CourseGrouping.group([
            event("Analyse III"), event("Analyse III"), event("Analyse III - TD"),
        ])
        #expect(groups[0].name == "Analyse III")
    }

    @Test("A egalite, le nom le plus court gagne")
    func shortestWinsOnTie() {
        // « Analyse III » vaut mieux que « Analyse III - CM - amphi B ».
        let groups = CourseGrouping.group([
            event("Analyse III"), event("Analyse III - CM - amphi B"),
        ])
        #expect(groups[0].name == "Analyse III")
    }

    @Test("La similarite est bien normalisee entre 0 et 1")
    func similarityBounds() {
        #expect(CourseGrouping.similarity("abc", "abc") == 1)
        #expect(CourseGrouping.similarity("abc", "xyz") == 0)
        #expect(CourseGrouping.similarity("", "") == 1)
    }

    @Test("Les groupes sortent du plus frequent au moins frequent")
    func sortedByFrequency() {
        let groups = CourseGrouping.group([
            event("Anglais"),
            event("Analyse III"), event("Analyse III"), event("Analyse III"),
        ])
        #expect(groups.map(\.name) == ["Analyse III", "Anglais"])
    }

    @Test("Les identifiants de creneaux sont conserves")
    func keepsUIDs() {
        let groups = CourseGrouping.group([
            event("Analyse III", uid: "a"), event("Analyse III", uid: "b"),
        ])
        #expect(Set(groups[0].uids) == ["a", "b"])
    }

    @Test("Un intitule vide est ignore")
    func skipsEmpty() {
        #expect(CourseGrouping.group([event("   ")]).isEmpty)
    }
}
