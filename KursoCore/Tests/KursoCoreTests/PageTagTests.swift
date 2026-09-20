import Testing
@testable import KursoCore

@Suite("Intercalaires d'un cahier")
struct PageTagTests {

    @Test("La liste est fermee")
    func closedList() {
        // C'est ce qui separe un intercalaire d'une arborescence : on le
        // choisit, on ne le construit pas (§12).
        #expect(PageTag.allCases.map(\.rawValue) == ["cours", "exercice", "td", "correction"])
        #expect(PageTag.named("mon-truc-a-moi") == nil)
        #expect(PageTag.named("exercice") == .exercice)
    }

    @Test("Chaque intercalaire a son libelle et sa couleur de la palette")
    func labelsAndColours() {
        for tag in PageTag.allCases {
            #expect(!tag.label.isEmpty)
            #expect(tag.colorToken.hasPrefix("#"))
        }
        #expect(Set(PageTag.allCases.map(\.colorToken)).count == PageTag.allCases.count)
    }

    @Test("On ne montre que les intercalaires qui portent une page")
    func onlyUsedDividers() {
        let tags = ["cours", "cours", "exercice", ""]
        #expect(PageTag.dividers(for: tags) == [.cours, .exercice])
        #expect(PageTag.count(.cours, in: tags) == 2)
        #expect(PageTag.count(.correction, in: tags) == 0)
    }

    @Test("Aucune page rangee : aucun intercalaire")
    func nothingFiled() {
        #expect(PageTag.dividers(for: ["", "", ""]).isEmpty)
    }

    @Test("Filtrer garde l'ordre, et « Tout » rend tout")
    func filtering() {
        let pages = [("a", "cours"), ("b", "exercice"), ("c", "cours")]
        #expect(PageTag.keep(pages, matching: .cours, tagOf: \.1).map(\.0) == ["a", "c"])
        #expect(PageTag.keep(pages, matching: nil, tagOf: \.1).map(\.0) == ["a", "b", "c"])
        #expect(PageTag.keep(pages, matching: .correction, tagOf: \.1).isEmpty)
    }

    @Test("Un intercalaire vide ne reste pas selectionne")
    func selectionFollowsReality() {
        // Sinon on se retrouve devant un cahier vide sans comprendre pourquoi :
        // la derniere page d'un intercalaire vient d'etre supprimee ou rangee
        // ailleurs.
        #expect(PageTag.stillThere(.cours, in: ["cours", "exercice"]) == .cours)
        #expect(PageTag.stillThere(.cours, in: ["exercice"]) == nil)
        #expect(PageTag.stillThere(nil, in: ["cours"]) == nil)
    }
}
