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

@Suite("Recherche — l'extrait")
struct TextSearchExcerptTests {

    @Test("L'extrait est la ligne qui contient le terme")
    func findsLine() {
        let text = "Tas binaires\nHauteur = log n\nInsertion par remontee"
        let excerpt = TextSearch.excerpt(from: text, query: "hauteur")
        #expect(excerpt?.line == "Hauteur = log n")
        #expect(excerpt?.highlights.count == 1)
    }

    @Test("Les accents se surlignent quand meme")
    func ignoresDiacritics() {
        // On tape « theoreme » sans accent, on doit surligner « théorème ».
        let excerpt = TextSearch.excerpt(from: "le théorème de Rolle", query: "theoreme")
        #expect(excerpt?.highlights.count == 1)
        let range = excerpt!.highlights[0]
        let line = Array(excerpt!.line)
        #expect(String(line[range.lowerBound..<range.upperBound]) == "théorème")
    }

    @Test("Plusieurs occurrences sur la meme ligne")
    func several() {
        let excerpt = TextSearch.excerpt(from: "tas puis tas", query: "tas")
        #expect(excerpt?.highlights.count == 2)
    }

    @Test("Une ligne trop longue est coupee autour du terme")
    func trimsLongLine() {
        let padding = String(repeating: "a ", count: 200)
        let excerpt = TextSearch.excerpt(from: padding + "heapify " + padding, query: "heapify")
        #expect(excerpt != nil)
        #expect(excerpt!.line.count <= 122)
        // Le surlignage designe toujours le bon mot apres la coupe.
        let line = Array(excerpt!.line)
        let range = excerpt!.highlights[0]
        #expect(String(line[range.lowerBound..<range.upperBound]) == "heapify")
    }

    @Test("Rien a montrer quand rien ne correspond")
    func noMatch() {
        #expect(TextSearch.excerpt(from: "rien ici", query: "zzz") == nil)
        #expect(TextSearch.excerpt(from: "rien ici", query: "  ") == nil)
    }
}
