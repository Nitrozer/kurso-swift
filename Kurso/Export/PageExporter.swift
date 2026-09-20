#if os(iOS)
import SwiftUI
import UIKit
import PencilKit
import KursoCore
import KursoModels

/// Export de pages en PDF.
///
/// On redessine tout : le fond — photo, diapo ou papier reglé — puis l'ecriture
/// par-dessus. Exporter le seul trace donnerait une feuille blanche parsemee,
/// illisible pour qui ne connait pas la page.
enum PageExporter {

    /// Un fichier PDF pour ces pages, dans l'ordre donne.
    @MainActor
    static func pdf(_ pages: [Page], backdrops: [UUID: CGImage] = [:]) -> Data {
        let full = CGRect(origin: .zero, size: PaperBackdrop.pageSize)
        let renderer = UIGraphicsPDFRenderer(bounds: full)
        return renderer.pdfData { context in
            for page in pages {
                let bounds = trimmed(page)
                context.beginPage(withBounds: bounds, pageInfo: [:])
                draw(page, in: bounds, context: context.cgContext,
                     image: backdrops[page.id] ?? backdrop(for: page))
            }
        }
    }

    /// La page entiere en une image : fond, trace, images posees, blocs de
    /// texte. Tout ce que l'export met dans le PDF.
    ///
    /// C'est le MEME dessin que l'export, a une autre echelle. Deux rendus
    /// differents pour la meme page finiraient par diverger, et l'apercu
    /// mentirait sur ce que la page contient.
    @MainActor
    static func image(_ page: Page, width: CGFloat, density: CGFloat = 2) -> UIImage? {
        let bounds = trimmed(page)
        guard bounds.width > 0, bounds.height > 0, width > 0 else { return nil }
        let ratio = width / bounds.width
        let format = UIGraphicsImageRendererFormat()
        // Une vignette veut de la finesse, une page entiere veut tenir en
        // memoire : a pleine largeur, doubler la densite quadruple le poids.
        format.scale = density
        format.opaque = true
        let size = CGSize(width: width, height: bounds.height * ratio)
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            context.cgContext.scaleBy(x: ratio, y: ratio)
            // JAMAIS sous 1 : PKDrawing ne rend rien en dessous, et l'encre
            // disparaissait purement et simplement de l'apercu. On economise
            // sur la densite, pas sur la presence.
            draw(page, in: bounds, context: context.cgContext,
                 image: backdrop(for: page), inkScale: max(ratio * 2, 1))
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
        // Une image ou un bloc de texte pose tout en bas doit tenir dans la
        // page exportee, meme si rien n'est ecrit a cette hauteur.
        for box in (page.images ?? []).map(\.rect) + (page.texts ?? []).map(\.rect) {
            used = max(used, placement(of: box).maxY + 80)
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
    ///
    /// Le rendu des diapos est la partie lente : on le fait page par page en
    /// rendant la main entre chacune, sinon un cahier epais gelait l'interface
    /// sans rien dire.
    @MainActor
    static func write(_ pages: [Page],
                      fallbackName: String,
                      progress: @escaping @MainActor (Double) -> Void = { _ in }) async -> URL? {
        guard !pages.isEmpty else { return nil }

        var backdrops: [UUID: CGImage] = [:]
        for (rank, page) in pages.enumerated() {
            if let image = backdrop(for: page) { backdrops[page.id] = image }
            progress(Double(rank + 1) / Double(pages.count + 1))
            await Task.yield()
        }

        let url = FileManager.default.temporaryDirectory
            .appending(path: fileName(for: pages, fallback: fallbackName))
        do {
            try pdf(pages, backdrops: backdrops).write(to: url, options: .atomic)
            progress(1)
            return url
        } catch {
            return nil
        }
    }

    // MARK: Une page

    @MainActor
    private static func draw(_ page: Page, in bounds: CGRect, context: CGContext,
                             image: CGImage?, inkScale: CGFloat = 2) {
        UIColor.white.setFill()
        context.fill(bounds)

        if let image {
            let fitted = PaperBackdrop.fitted(
                CGSize(width: image.width, height: image.height), into: bounds)
            UIImage(cgImage: image).draw(in: fitted)
        } else {
            rules(in: bounds, context: context)
        }

        if let data = page.drawing,
           let drawing = try? PKDrawing(data: data),
           !drawing.strokes.isEmpty {
            drawing.image(from: bounds, scale: inkScale).draw(in: bounds)
        }

        // Ce qu'on a pose PAR-DESSUS le trace : images deplacees, blocs de
        // texte tapes. Ils manquaient a l'export — une page exportee perdait
        // en silence tout ce qui n'etait pas ecrit au stylet.
        for item in (page.images ?? []).sorted(by: { $0.order < $1.order }) {
            guard let data = item.data, let image = UIImage(data: data) else { continue }
            image.draw(in: placement(of: item.rect))
        }
        for item in (page.texts ?? []).sorted(by: { $0.order < $1.order }) {
            text(of: item)?.draw(in: placement(of: item.rect))
        }
    }

    /// Un cadre en fractions de page redevient des points.
    ///
    /// Toujours rapporte a la page ENTIERE, jamais au cadre rogne : c'est
    /// ainsi que les fractions ont ete enregistrees, et une image calee sur
    /// un cadre plus court remonterait vers le haut.
    private static func placement(of box: CGRect) -> CGRect {
        CGRect(x: box.minX * PaperBackdrop.pageWidth,
               y: box.minY * PaperBackdrop.pageHeight,
               width: box.width * PaperBackdrop.pageWidth,
               height: box.height * PaperBackdrop.pageHeight)
    }

    private static func text(of item: PageText) -> NSAttributedString? {
        if let rtf = item.rtf,
           let attributed = try? NSAttributedString(
                data: rtf,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil) {
            return attributed
        }
        guard !item.plain.isEmpty else { return nil }
        return NSAttributedString(string: item.plain, attributes: [
            .font: UIFont(name: "Nunito-SemiBold", size: 17) ?? .systemFont(ofSize: 17),
            .foregroundColor: UIColor(Color(token: DesignTokens.Palette.ink)),
        ])
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
