import Foundation
import Testing
@testable import KursoCore

@Suite("Carte du semestre")
struct MemoryMapTests {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func input(_ day: Double, cards: [Freshness.CardState] = []) -> MemoryMap.Input {
        .init(id: UUID(), title: "Page", date: now.addingTimeInterval(day * 86_400), cards: cards)
    }

    private var fresh: Freshness.CardState {
        .init(dueAt: now.addingTimeInterval(86_400), interval: 30)
    }

    @Test("Une carte vide n'a ni noeud ni arete")
    func empty() {
        let layout = MemoryMap.layout([], now: now)
        #expect(layout.nodes.isEmpty)
        #expect(layout.edges.isEmpty)
    }

    @Test("Les aretes suivent l'ordre chronologique")
    func edgesFollowTime() {
        let layout = MemoryMap.layout([input(3), input(1), input(2)], now: now)
        #expect(layout.nodes.count == 3)
        #expect(layout.edges.count == 2)
        // Chaque arete part du noeud precedent dans le temps.
        #expect(layout.edges[0].from == layout.nodes[0].id)
        #expect(layout.edges[0].to == layout.nodes[1].id)
        #expect(layout.nodes[0].date < layout.nodes[1].date)
    }

    @Test("Les positions restent dans le cadre")
    func withinBounds() {
        let layout = MemoryMap.layout((0..<40).map { input(Double($0)) }, now: now)
        #expect(layout.nodes.allSatisfy { $0.x >= 0 && $0.x <= 1 })
        #expect(layout.nodes.allSatisfy { $0.y >= 0 && $0.y <= 1 })
    }

    @Test("Le temps descend")
    func timeGoesDown() {
        let layout = MemoryMap.layout((0..<10).map { input(Double($0)) }, now: now)
        let ys = layout.nodes.map(\.y)
        #expect(ys == ys.sorted())
    }

    @Test("Un seul noeud se pose au milieu")
    func singleNode() {
        let layout = MemoryMap.layout([input(0)], now: now)
        #expect(layout.nodes.first?.y == 0.5)
        #expect(layout.edges.isEmpty)
    }

    @Test("La disposition ne bouge pas d'une ouverture a l'autre")
    func deterministic() {
        // Une carte qui se redispose a chaque fois ne se memorise pas.
        let inputs = (0..<12).map { input(Double($0)) }
        let first = MemoryMap.layout(inputs, now: now)
        let again = MemoryMap.layout(inputs, now: now)
        #expect(first == again)
    }

    @Test("Les pastilles suivent l'etat")
    func dots() {
        #expect(MemoryMap.dots(for: .acquired) == 3)
        #expect(MemoryMap.dots(for: .draft) == 0)
        let layout = MemoryMap.layout([input(0, cards: [fresh])], now: now)
        #expect(layout.nodes.first?.state == .acquired)
        #expect(layout.nodes.first?.dots == 3)
    }

    @Test("Une page sans carte est un brouillon")
    func draft() {
        let layout = MemoryMap.layout([input(0)], now: now)
        #expect(layout.nodes.first?.state == .draft)
    }
}
