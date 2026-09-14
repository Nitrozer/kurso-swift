import Foundation

/// Le papier d'une page.
///
/// Quatre modeles, tous gratuits : du quadrillé pour des maths n'est pas un
/// ornement, c'est une necessite. Le §9 reserve les copeaux a l'apparence,
/// pas a ce qui sert.
public enum PaperKind: String, CaseIterable, Sendable {
    case ruled, grid, dotted, blank

    public var label: String {
        switch self {
        case .ruled:  "Ligné"
        case .grid:   "Quadrillé"
        case .dotted: "Pointillé"
        case .blank:  "Blanc"
        }
    }

    public static func named(_ raw: String) -> PaperKind {
        PaperKind(rawValue: raw) ?? .ruled
    }
}
