#if os(iOS)
import UIKit
import KursoModels

/// Le cache des apercus de page.
///
/// Un apercu redessine la page entiere : sans cache, faire defiler le panneau
/// des pages relancerait ce rendu a chaque image de l'animation. On le refait
/// uniquement quand la page a reellement change.
@MainActor
enum PageThumbnails {
    private static var cache: [UUID: (signature: String, image: UIImage)] = [:]

    /// Ce qui, en changeant, doit refaire l'apercu.
    ///
    /// Les positions y figurent, pas seulement les nombres : deplacer une
    /// image ne change aucun compte, et l'apercu serait reste celui d'avant.
    static func signature(_ page: Page) -> String {
        var parts = [
            "t\(page.drawing?.count ?? 0)",
            "p\(page.photo?.count ?? 0)",
            "d\(page.pdfAssetID?.uuidString ?? "")-\(page.pdfPageIndex ?? -1)",
        ]
        for item in (page.images ?? []).sorted(by: { $0.order < $1.order }) {
            parts.append("i\(item.data?.count ?? 0)@\(round(item.x * 1_000))-\(round(item.y * 1_000))-\(round(item.width * 1_000))")
        }
        for item in (page.texts ?? []).sorted(by: { $0.order < $1.order }) {
            parts.append("x\(item.plain.count)@\(round(item.x * 1_000))-\(round(item.y * 1_000))-\(round(item.height * 1_000))")
        }
        return parts.joined(separator: "|")
    }

    static func image(for page: Page, width: CGFloat) -> UIImage? {
        let key = signature(page)
        if let kept = cache[page.id], kept.signature == key { return kept.image }
        guard let made = PageExporter.image(page, width: width) else { return nil }
        // Un cahier entier tient largement sous cette barre ; au-dela, on
        // repart de zero plutot que de tenir une liste de dates d'usage.
        if cache.count > 120 { cache.removeAll() }
        cache[page.id] = (key, made)
        return made
    }
}
#endif
