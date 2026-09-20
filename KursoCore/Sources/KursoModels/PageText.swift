import Foundation
import SwiftData

/// Un bloc de texte tape au clavier, pose sur la page.
///
/// Tout ne s'ecrit pas au stylet : une definition qu'on recopie d'un poly, un
/// enonce, une liste de references. Le bloc se deplace comme une image, et son
/// cadre est enregistre en fractions de page — c'est la seule facon qu'il
/// tienne au zoom.
@Model public final class PageText {
    public var id: UUID = UUID()

    /// Le texte mis en forme, en RTF. Hors de la base : de la mise en forme
    /// n'a rien a faire dans un enregistrement SwiftData (§1).
    @Attribute(.externalStorage) public var rtf: Data?

    /// Le meme texte, nu.
    ///
    /// Recopie a chaque enregistrement, donc redondant — et c'est voulu. La
    /// recherche parcourt toutes les pages de tous les cahiers : decoder du
    /// RTF a chaque frappe couterait bien plus cher que ce doublon.
    public var plain: String = ""

    public var x: Double = 0.08
    public var y: Double = 0.05
    public var width: Double = 0.6
    /// Suit le texte : un bloc ne se retaille pas en hauteur, il grandit.
    public var height: Double = 0.05
    /// Ordre d'empilement : le dernier pose passe devant.
    public var order: Double = 0

    public var page: Page?

    public init(plain: String = "") {
        self.plain = plain
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
