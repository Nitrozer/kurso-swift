import Foundation
import CoreGraphics

/// Ou poser une image dans une page.
///
/// Un seul endroit calcule ce placement, et il vit hors de SwiftUI (§11bis).
/// Le fond, le masquage et la capture s'en servent tous : les laisser calculer
/// chacun de leur cote est precisement ce qui faisait tomber les masques a
/// cote de ce qu'on visait.
public enum ImagePlacement {

    /// L'image ajustee dans le cadre, sans deformation, callee en haut.
    public static func fitted(_ size: CGSize, into rect: CGRect) -> CGRect {
        guard size.width > 0, size.height > 0, rect.width > 0, rect.height > 0 else { return rect }
        let scale = min(rect.width / size.width, rect.height / size.height)
        let width = size.width * scale
        let height = size.height * scale
        return CGRect(x: rect.midX - width / 2, y: rect.minY, width: width, height: height)
    }

    /// L'image a la taille reglee par l'etudiant, ou ajustee a defaut.
    ///
    /// - Parameter box: le cadre voulu, en fractions de la page.
    public static func placement(image: CGSize, box: CGRect?, in pageRect: CGRect) -> CGRect {
        guard let box, box.width > 0, box.height > 0 else {
            return fitted(image, into: pageRect)
        }
        return CGRect(x: pageRect.minX + box.minX * pageRect.width,
                      y: pageRect.minY + box.minY * pageRect.height,
                      width: box.width * pageRect.width,
                      height: box.height * pageRect.height)
    }

    /// Le chemin inverse : un cadre a l'ecran redevient des fractions de page.
    public static func box(from rect: CGRect, in pageRect: CGRect) -> CGRect? {
        guard pageRect.width > 0, pageRect.height > 0 else { return nil }
        return CGRect(x: (rect.minX - pageRect.minX) / pageRect.width,
                      y: (rect.minY - pageRect.minY) / pageRect.height,
                      width: rect.width / pageRect.width,
                      height: rect.height / pageRect.height)
    }
}
