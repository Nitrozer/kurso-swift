import Foundation
import SwiftData

/// Une image posee sur une page, a l'endroit et a la taille voulus.
///
/// Distincte de la photo de fond : on en met plusieurs, on les deplace, on
/// les retaille. Le cadre est enregistre en fractions de page — c'est la
/// seule facon qu'il tienne au zoom.
@Model public final class PageImage {
    public var id: UUID = UUID()
    @Attribute(.externalStorage) public var data: Data?
    public var x: Double = 0.1
    public var y: Double = 0.05
    public var width: Double = 0.5
    public var height: Double = 0.3
    /// Ordre d'empilement : la derniere posee passe devant.
    public var order: Double = 0

    public var page: Page?

    public init(data: Data? = nil) {
        self.data = data
    }

    /// Vue pratique sur le cadre.
    public var rect: CGRect {
        get { CGRect(x: x, y: y, width: width, height: height) }
        set {
            x = newValue.minX
            y = newValue.minY
            width = newValue.width
            height = newValue.height
        }
    }
}
