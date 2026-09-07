import Testing
@testable import KursoCore

@Suite("Titre de page — §4")
struct PageTitleTests {

    @Test("La premiere ligne devient le titre")
    func firstLine() {
        #expect(PageTitle.derive(from: "Graphes orientes\nsuite du cours") == "Graphes orientes")
    }

    @Test("Les lignes vides du debut sont ignorees")
    func skipsLeadingBlanks() {
        #expect(PageTitle.derive(from: "\n\n   \nDijkstra") == "Dijkstra")
    }

    @Test("Les dieses markdown ne font pas partie du titre")
    func stripsHeadingMarkers() {
        #expect(PageTitle.derive(from: "## Complexite amortie") == "Complexite amortie")
    }

    @Test("La ponctuation finale est retiree")
    func stripsTrailingPunctuation() {
        #expect(PageTitle.derive(from: "Theoreme de Kruskal.") == "Theoreme de Kruskal")
        #expect(PageTitle.derive(from: "Pourquoi ca marche ?") == "Pourquoi ca marche")
        #expect(PageTitle.derive(from: "Plan du cours :") == "Plan du cours")
    }

    @Test("Une parenthese fermante n'est pas de la ponctuation finale")
    func keepsClosingBracket() {
        #expect(PageTitle.derive(from: "Tri fusion (recursif)") == "Tri fusion (recursif)")
    }

    @Test("Le titre est tronque a 60 caracteres")
    func truncates() {
        let long = String(repeating: "a", count: 100)
        #expect(PageTitle.derive(from: long)?.count == 60)
    }

    @Test("Un texte vide ne propose aucun titre")
    func emptyGivesNil() {
        #expect(PageTitle.derive(from: "") == nil)
        #expect(PageTitle.derive(from: "\n   \n") == nil)
    }

    @Test("Une ligne faite seulement de ponctuation ne propose aucun titre")
    func punctuationOnlyGivesNil() {
        // Sans ce cas, on ecraserait un titre existant par une chaine vide.
        #expect(PageTitle.derive(from: "###") == nil)
        #expect(PageTitle.derive(from: "...") == nil)
    }
}
