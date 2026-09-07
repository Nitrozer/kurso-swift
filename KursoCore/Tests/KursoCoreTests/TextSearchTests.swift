import Testing
@testable import KursoCore

@Suite("Recherche dans l'ecriture")
struct TextSearchTests {

    struct Page: Equatable { let name: String; let text: String }

    let pages = [
        Page(name: "tri",      text: "Tri fusion et Karatsuba"),
        Page(name: "geo",      text: "Geometrie du triangle"),
        Page(name: "theoreme", text: "Théorème de Kruskal"),
        Page(name: "vide",     text: ""),
    ]

    func names(_ q: String) -> [String] {
        TextSearch.rank(pages, query: q) { $0.text }.map(\.item.name)
    }

    @Test("Une requete vide ne rend rien")
    func emptyQuery() {
        #expect(names("").isEmpty)
        #expect(names("   ").isEmpty)
    }

    @Test("Les accents sont ignores dans les deux sens")
    func accentInsensitive() {
        // Taper les accents pendant un cours n'arrive pas.
        #expect(names("theoreme") == ["theoreme"])
        #expect(names("théorème") == ["theoreme"])
    }

    @Test("La casse est ignoree")
    func caseInsensitive() {
        #expect(names("KRUSKAL") == ["theoreme"])
    }

    @Test("Un mot entier passe devant un fragment")
    func wholeWordRanksFirst() {
        // « tri » est un mot dans « Tri fusion », un fragment dans « triangle ».
        #expect(names("tri") == ["tri", "geo"])
    }

    @Test("Un debut de mot passe devant un milieu de mot")
    func prefixBeatsMiddle() {
        let items = [
            Page(name: "milieu", text: "abcfusion"),
            Page(name: "debut",  text: "fusionner les tas"),
        ]
        let ranked = TextSearch.rank(items, query: "fusion") { $0.text }.map(\.item.name)
        #expect(ranked == ["debut", "milieu"])
    }

    @Test("Une page sans texte reconnu n'est jamais un resultat")
    func emptyTextNeverMatches() {
        #expect(names("tri").contains("vide") == false)
    }

    @Test("Une requete absente ne rend rien")
    func noMatch() {
        #expect(names("dijkstra").isEmpty)
    }
}
