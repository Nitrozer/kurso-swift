import Testing
import Foundation
@testable import KursoModels

/// « Ouvrir le cahier » doit retrouver la page du jour, pas en empiler une
/// nouvelle a chaque appui. Hors creneau, l'emploi du temps ne rattache rien :
/// c'est la que les pages orphelines s'accumulaient.
@Suite("Page du jour d'un cours")
struct DayPageTests {

    @Test("La page du jour est retrouvee")
    func findsTodaysPage() {
        let course = Course(name: "Automatique")
        let page = Page(createdAt: .now)
        page.course = course
        #expect(Page.today(for: course, among: [page])?.id == page.id)
    }

    @Test("Une page d'hier ne compte pas")
    func ignoresYesterday() {
        let course = Course(name: "Analyse")
        let old = Page(createdAt: .now.addingTimeInterval(-86_400))
        old.course = course
        #expect(Page.today(for: course, among: [old]) == nil)
    }

    @Test("Une page d'une autre matiere ne compte pas")
    func ignoresOtherCourse() {
        let physique = Course(name: "Physique")
        let anglais = Course(name: "Anglais")
        let page = Page(createdAt: .now)
        page.course = physique
        #expect(Page.today(for: anglais, among: [page]) == nil)
    }

    @Test("Une page orpheline n'est jamais reprise")
    func ignoresOrphan() {
        let course = Course(name: "Statistiques")
        let orphan = Page(createdAt: .now)
        #expect(Page.today(for: course, among: [orphan]) == nil)
        #expect(Page.today(for: nil, among: [orphan]) == nil)
    }
}
