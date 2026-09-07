import Foundation
import SwiftData

/// Memoire des refus par marqueur (§5).
///
/// « Si l'etudiant refuse trois propositions issues du meme marqueur, ce
/// marqueur est desactive pour lui. Sans reglage, sans message. » D'ou ce
/// compteur discret plutot qu'un ecran de preferences.
@Model public final class MarkerFeedback {
    public var id: UUID = UUID()
    public var marker: String = ""
    public var rejections: Int = 0

    /// Seuil du §5.
    public static let disableThreshold = 3

    public var isDisabled: Bool { rejections >= Self.disableThreshold }

    public init(marker: String = "") { self.marker = marker }
}
