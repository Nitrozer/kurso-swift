#if os(iOS)
import UIKit
import PencilKit
import KursoModels

/// Export de pages en PDF.
///
/// On redessine tout : le fond — photo, diapo ou papier reglé — puis l'ecriture
/// par-dessus. Exporter le seul trace donnerait une feuille blanche parsemee,
/// illisible pour qui ne connait pas la page.
enum PageExporter {

    /// Un fichier PDF pour ces pages, dans l'ordre donne.
    @MainActor
    static func pdf(_ pages: [Page]) -> Data {
        let full = CGRect(origin: .zero, size: PaperBackdrop.pageSize)
        let renderer = UIGraphicsPDFRenderer(bounds: full)
        return renderer.pdfData { context in
            for page in pages {
                let bounds = trimmed(page)
                context.beginPage(withBounds: bounds, pageInfo: [:])
                draw(page, in: bounds, context: context.cgContext)
            }
        }
    }

    /// La hauteur reellement occupee, jamais les 3000 points du canevas.
    ///
    /// Une page a peine ecrite s'exportait en bande de 1240 x 3000 :
    /// impossible a imprimer, illisible a l'ecran. On s'arrete apres le
    /// dernier trait, sans jamais descendre sous un A4.
    @MainActor
    static func trimmed(_ page: Page) -> CGRect {
        let width = PaperBackdrop.pageWidth
        let a4 = width * 297 / 210          // un A4 a cette largeur
        var used = a4

        if let image = backdrop(for: page) {
            let fitted = PaperBackdrop.fitted(
                CGSize(width: image.width, height: image.height),
                into: CGRect(origin: .zero, size: PaperBackdrop.pageSize))
            used = max(used, fitted.height)
        }
        if let data = page.drawing,
           let drawing = try? PKDrawing(data: data),
           !drawing.strokes.isEmpty {
            used = max(used, drawing.bounds.maxY + 160)
        }
        return CGRect(x: 0, y: 0, width: width, height: min(used, PaperBackdrop.pageHeight))
    }

    /// Nom de fichier lisible, sans caractere interdit.
    static func fileName(for pages: [Page], fallback: String) -> String {
        let base = pages.count == 1
            ? (pages.first?.title.isEmpty == false ? pages[0].title : fallback)
            : fallback
        let cleaned = base
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (cleaned.isEmpty ? fallback : cleaned) + ".pdf"
    }

    /// Ecrit le PDF dans un fichier temporaire, pret a partager.
    @MainActor
    static func write(_ pages: [Page], fallbackName: String) -> URL? {
        guard !pages.isEmpty else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appending(path: fileName(for: pages, fallback: fallbackName))
        do {
            try pdf(pages).write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    // MARK: Une page

    @MainActor
    private static func draw(_ page: Page, in bounds: CGRect, context: CGContext) {
        UIColor.white.setFill()
        context.fill(bounds)

        if let image = backdrop(for: page) {
            let fitted = PaperBackdrop.fitted(
                CGSize(width: image.width, height: image.height), into: bounds)
            UIImage(cgImage: image).draw(in: fitted)
        } else {
            rules(in: bounds, context: context)
        }

        if let data = page.drawing,
           let drawing = try? PKDrawing(data: data),
           !drawing.strokes.isEmpty {
            drawing.image(from: bounds, scale: 2).draw(in: bounds)
        }
    }

    @MainActor
    private static func backdrop(for page: Page) -> CGImage? {
        if let photo = page.photo { return UIImage(data: photo)?.cgImage }
        guard let assetID = page.pdfAssetID, let index = page.pdfPageIndex,
              let fileName = PDFAssetLookup.fileName(for: assetID) else { return nil }
        return PDFStore.render(fileName: fileName, pageIndex: index,
                               width: PaperBackdrop.pageWidth * 2)
    }

    /// Le papier reglé, redessine pour l'export.
    private static func rules(in bounds: CGRect, context: CGContext) {
        let spacing: CGFloat = 32
        context.setLineWidth(1)
        UIColor(red: 0.847, green: 0.867, blue: 0.937, alpha: 1).setStroke()
        var y = spacing
        while y < bounds.height {
            context.move(to: CGPoint(x: 0, y: y))
            context.addLine(to: CGPoint(x: bounds.width, y: y))
            y += spacing
        }
        context.strokePath()

        UIColor(red: 1, green: 0.612, blue: 0.639, alpha: 0.55).setStroke()
        context.setLineWidth(1.5)
        context.move(to: CGPoint(x: 96, y: 0))
        context.addLine(to: CGPoint(x: 96, y: bounds.height))
        context.strokePath()
    }
}

/// Retrouve le fichier d'un PDF depuis son identifiant.
///
/// Le modele ne porte que l'identifiant : sans cette table, l'export ne
/// saurait pas quelle diapo redessiner.
@MainActor
enum PDFAssetLookup {
    nonisolated(unsafe) private static var cache: [UUID: String] = [:]

    static func remember(_ assets: [PDFAsset]) {
        for asset in assets { cache[asset.id] = asset.fileName }
    }

    static func fileName(for id: UUID) -> String? { cache[id] }
}
#endif
