import Foundation

/// La carte du semestre (§3) : ou se placent les noeuds et leurs aretes.
///
/// Le §1 le dit — « lien chronologique = arete de la carte ». On ne calcule
/// donc pas un graphe de similarite : on suit l'ordre dans lequel les pages
/// ont ete ecrites, ce qui est aussi l'ordre dans lequel on les a apprises.
///
/// La mise en page est **deterministe**. Une carte qui se redispose a chaque
/// ouverture ne se memorise pas, et c'est precisement ce qu'on lui demande.
public enum MemoryMap {

    public struct Input: Equatable, Sendable {
        public let id: UUID
        public let title: String
        public let date: Date
        public let cards: [Freshness.CardState]

        public init(id: UUID, title: String, date: Date, cards: [Freshness.CardState]) {
            self.id = id
            self.title = title
            self.date = date
            self.cards = cards
        }
    }

    public struct Node: Equatable, Sendable, Identifiable {
        public let id: UUID
        public let title: String
        public let date: Date
        public let state: Freshness.State
        public let cardCount: Int
        /// 0 a 3 : les pastilles sous le noeud.
        public let dots: Int
        /// Position relative, 0 a 1.
        public let x: Double
        public let y: Double
    }

    public struct Edge: Equatable, Sendable, Identifiable {
        public let from: UUID
        public let to: UUID
        public var id: String { "\(from)-\(to)" }
    }

    public struct Layout: Equatable, Sendable {
        public var nodes: [Node]
        public var edges: [Edge]

        public func node(_ id: UUID) -> Node? { nodes.first { $0.id == id } }
    }

    /// De combien la colonne s'ecarte de l'axe. Assez pour que le trace
    /// respire, pas assez pour qu'on perde le fil.
    public static let sway = 0.26

    public static func layout(_ inputs: [Input], now: Date = .now) -> Layout {
        let ordered = inputs.sorted { $0.date == $1.date ? $0.id.uuidString < $1.id.uuidString : $0.date < $1.date }
        guard !ordered.isEmpty else { return Layout(nodes: [], edges: []) }

        let last = max(1, ordered.count - 1)
        let nodes = ordered.enumerated().map { index, input -> Node in
            let state = Freshness.state(cards: input.cards, now: now)
            return Node(
                id: input.id,
                title: input.title,
                date: input.date,
                state: state,
                cardCount: input.cards.count,
                dots: dots(for: state),
                // Un balancement regulier plutot qu'un hasard : la meme carte
                // se retrouve au meme endroit, semaine apres semaine.
                x: 0.5 + sway * sin(Double(index) * 1.1),
                y: ordered.count == 1 ? 0.5 : Double(index) / Double(last)
            )
        }

        let edges = zip(nodes, nodes.dropFirst()).map { Edge(from: $0.id, to: $1.id) }
        return Layout(nodes: nodes, edges: edges)
    }

    /// Les trois pastilles sous un noeud, comme sur la maquette.
    public static func dots(for state: Freshness.State) -> Int {
        switch state {
        case .acquired:   3
        case .toReview:   2
        case .endangered: 1
        case .draft:      0
        }
    }

    /// La ligne du bas : ce que chaque couleur veut dire.
    public static let legend: [(state: Freshness.State, label: String)] = [
        (.acquired, "fraîche"),
        (.toReview, "pâlit"),
        (.endangered, "presque effacée"),
        (.draft, "brouillon"),
    ]
}
