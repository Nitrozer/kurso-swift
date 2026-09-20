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

@Suite("Deplacer un bloc de pages")
struct PageMoveTests {

    private let a = UUID(), b = UUID(), c = UUID(), d = UUID()

    private var cahier: [(id: UUID, position: Double)] {
        [(a, 0), (b, 1_000), (c, 2_000), (d, 3_000)]
    }

    private func ordre(_ changed: [UUID: Double]) -> [UUID] {
        cahier.map { (id: $0.id, position: changed[$0.id] ?? $0.position) }
            .sorted { $0.position < $1.position }
            .map(\.id)
    }

    @Test("Un PDF ajoute a la suite passe tout entier devant")
    func wholePdfToTheFront() {
        // Le cas qui revient : on importe, puis on veut le voir en premier.
        let changed = PageOrdering.moved([c, d], to: .start, among: cahier)
        #expect(ordre(changed) == [c, d, a, b])
    }

    @Test("L'ordre relatif des pages deplacees est conserve")
    func relativeOrderKept() {
        let changed = PageOrdering.moved([a, c], to: .end, among: cahier)
        #expect(ordre(changed) == [b, d, a, c])
    }

    @Test("Une selection eparpillee se retrouve groupee")
    func scatteredBecomesContiguous() {
        let changed = PageOrdering.moved([a, c], to: .start, among: cahier)
        #expect(ordre(changed) == [a, c, b, d])
    }

    @Test("Les pages qui ne bougent pas gardent leur rang")
    func othersUntouched() {
        // Pas de renumerotation : bouger trois pages ne doit pas reecrire
        // tout le cahier.
        let changed = PageOrdering.moved([d], to: .start, among: cahier)
        #expect(changed.keys.map { $0 } == [d])
    }

    @Test("Tout deplacer ne deplace rien")
    func movingEverythingIsANoOp() {
        // Il n'y a pas d'ailleurs.
        #expect(PageOrdering.moved([a, b, c, d], to: .start, among: cahier).isEmpty)
        #expect(PageOrdering.moved([], to: .end, among: cahier).isEmpty)
    }

    @Test("Les rangs restent assez espaces pour qu'on insere entre eux")
    func stillRoomToInsert() {
        let changed = PageOrdering.moved([d], to: .start, among: cahier)
        let all = cahier.map { changed[$0.id] ?? $0.position }
        #expect(!PageOrdering.needsRenumbering(all))
    }
}

@Suite("Glisser une page dans le cahier")
struct PageDropTests {

    private let a = UUID(), b = UUID(), c = UUID()

    private var cahier: [(id: UUID, position: Double)] {
        [(a, 0), (b, 1_000), (c, 2_000)]
    }

    private func ordre(_ changed: [UUID: Double], in pages: [(id: UUID, position: Double)]? = nil) -> [UUID] {
        (pages ?? cahier).map { (id: $0.id, position: changed[$0.id] ?? $0.position) }
            .sorted { $0.position < $1.position }
            .map(\.id)
    }

    @Test("Lachee au-dessus de la premiere, elle devient la premiere")
    func toTheFront() {
        #expect(ordre(PageOrdering.dropped(c, onto: a, above: true, among: cahier)) == [c, a, b])
    }

    @Test("Lachee sous la derniere, elle devient la derniere")
    func toTheBack() {
        #expect(ordre(PageOrdering.dropped(a, onto: c, above: false, among: cahier)) == [b, c, a])
    }

    @Test("Lachee au milieu, elle se glisse entre les deux")
    func inBetween() {
        #expect(ordre(PageOrdering.dropped(c, onto: b, above: true, among: cahier)) == [a, c, b])
        #expect(ordre(PageOrdering.dropped(a, onto: b, above: false, among: cahier)) == [b, a, c])
    }

    @Test("Lachee sur elle-meme, rien ne bouge")
    func ontoItself() {
        #expect(PageOrdering.dropped(b, onto: b, above: true, among: cahier).isEmpty)
    }

    @Test("Une seule page change de rang")
    func onlyOneMoves() {
        let changed = PageOrdering.dropped(c, onto: a, above: true, among: cahier)
        #expect(changed.count == 1)
    }

    @Test("Des rangs qui se touchent sont rouverts")
    func renumbersWhenCramped() {
        // A force de couper en deux, deux rangs finissent par se rejoindre :
        // sans renumerotation, l'ordre deviendrait celui du hasard.
        let serres: [(id: UUID, position: Double)] = [(a, 0), (b, 0.0000001), (c, 0.0000002)]
        let changed = PageOrdering.dropped(c, onto: a, above: true, among: serres)
        #expect(changed.count == 3)
        #expect(ordre(changed, in: serres) == [c, a, b])
        let apres = serres.map { changed[$0.id] ?? $0.position }
        #expect(!PageOrdering.needsRenumbering(apres))
    }
}
