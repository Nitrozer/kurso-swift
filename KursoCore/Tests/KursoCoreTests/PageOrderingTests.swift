import Testing
import Foundation
@testable import KursoCore

@Suite("Ordre des pages d'un cahier")
struct PageOrderingTests {

    @Test("Un cahier vide commence a zero")
    func firstPage() {
        #expect(PageOrdering.position(after: nil, before: nil) == 0)
    }

    @Test("Ajouter a la suite laisse de la place")
    func appendLeavesRoom() {
        #expect(PageOrdering.append(to: [0, 1_000]) == 2_000)
        #expect(PageOrdering.append(to: []) == 0)
    }

    @Test("Inserer entre deux pages prend leur milieu")
    func insertBetween() {
        #expect(PageOrdering.position(after: 1_000, before: 2_000) == 1_500)
    }

    @Test("Inserer tout en haut passe avant la premiere")
    func insertAtTop() {
        let p = PageOrdering.position(after: nil, before: 0)
        #expect(p < 0)
    }

    @Test("Insertions repetees restent ordonnees")
    func repeatedInsertsStayOrdered() {
        var a = 0.0, b = 1_000.0
        for _ in 0..<12 {
            let middle = PageOrdering.position(after: a, before: b)
            #expect(middle > a && middle < b)
            b = middle
        }
        #expect(a < b)
    }

    @Test("On repere quand les rangs se rejoignent")
    func detectsCollapse() {
        #expect(!PageOrdering.needsRenumbering([0, 1_000, 2_000]))
        #expect(PageOrdering.needsRenumbering([0, 0.0000001, 1_000]))
    }

    @Test("La renumerotation reespace tout")
    func renumbering() {
        let fresh = PageOrdering.renumbered(count: 4)
        #expect(fresh == [0, 1_000, 2_000, 3_000])
        #expect(!PageOrdering.needsRenumbering(fresh))
    }
}
