import Foundation
import PDFKit

/// Rangement des PDF deposes.
///
/// Les fichiers vivent dans le conteneur de l'app, pas dans la base : SwiftData
/// n'est pas fait pour des dizaines de megaoctets, et les garder en fichiers
/// permet a PDFKit de les lire par morceaux plutot que tout charger.
enum PDFStore {

    static var directory: URL {
        let base = URL.documentsDirectory.appending(path: "PDFs", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    static func url(for fileName: String) -> URL {
        directory.appending(path: fileName)
    }

    /// Copie le fichier choisi dans le conteneur et rend son nom et son nombre
    /// de pages. Une copie, pas une reference : le fichier d'origine peut etre
    /// dans un dossier temporaire que le systeme effacera.
    static func store(from source: URL) throws -> (fileName: String, title: String, pageCount: Int) {
        let needsAccess = source.startAccessingSecurityScopedResource()
        defer { if needsAccess { source.stopAccessingSecurityScopedResource() } }

        let fileName = "\(UUID().uuidString).pdf"
        let destination = url(for: fileName)
        try FileManager.default.copyItem(at: source, to: destination)

        let pageCount = PDFDocument(url: destination)?.pageCount ?? 0
        let title = source.deletingPathExtension().lastPathComponent
        return (fileName, title, pageCount)
    }

    static func document(fileName: String) -> PDFDocument? {
        PDFDocument(url: url(for: fileName))
    }

    /// Rend une page en image, pour l'afficher sous le canevas.
    ///
    /// CoreGraphics directement plutot qu'un moteur de rendu par plateforme :
    /// le meme code sert sur iPad et sur Mac, sans garde de compilation.
    /// Le texte d'une diapo, tel que le PDF le porte.
    ///
    /// Rend une chaine vide pour une page scannee : il n'y a alors rien a
    /// lire, et c'est une reponse, pas un echec.
    static func text(fileName: String, pageIndex: Int) -> String {
        guard let page = document(fileName: fileName)?.page(at: pageIndex) else { return "" }
        return (page.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func render(fileName: String, pageIndex: Int, width: CGFloat) -> CGImage? {
        render(document: document(fileName: fileName), pageIndex: pageIndex, width: width)
    }

    /// Meme rendu, depuis un fichier qui n'est pas encore depose : c'est ce
    /// qui sert a montrer les apercus avant de choisir les pages a garder.
    static func render(at url: URL, pageIndex: Int, width: CGFloat) -> CGImage? {
        render(document: PDFDocument(url: url), pageIndex: pageIndex, width: width)
    }

    private static func render(document: PDFDocument?, pageIndex: Int, width: CGFloat) -> CGImage? {
        guard width > 0,
              let document,
              pageIndex >= 0, pageIndex < document.pageCount,
              let page = document.page(at: pageIndex)
        else { return nil }

        let bounds = page.bounds(for: .mediaBox)
        guard bounds.width > 0, bounds.height > 0 else { return nil }

        let scale = width / bounds.width
        let pixelWidth = Int(bounds.width * scale)
        let pixelHeight = Int(bounds.height * scale)
        guard pixelWidth > 0, pixelHeight > 0 else { return nil }

        guard let context = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }

        // Fond blanc : un PDF sans fond laisserait apparaitre du noir.
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -bounds.origin.x, y: -bounds.origin.y)
        page.draw(with: .mediaBox, to: context)

        return context.makeImage()
    }

    /// Rend UNE PORTION de page, a la resolution de l'ecran.
    ///
    /// Re-rendre la page entiere en zoomant est impossible : a 5x un A4
    /// demanderait pres de 900 Mo. On ne rend donc que ce qui est visible,
    /// ce qui garde un cout constant quel que soit le zoom.
    ///
    /// `crop` est normalise entre 0 et 1, origine en HAUT a gauche — comme a
    /// l'ecran, pas comme dans le repere PDF.
    static func render(fileName: String, pageIndex: Int,
                       crop: CGRect, pixelWidth: Int) -> CGImage? {
        guard pixelWidth > 0, crop.width > 0, crop.height > 0,
              let document = document(fileName: fileName),
              pageIndex >= 0, pageIndex < document.pageCount,
              let page = document.page(at: pageIndex)
        else { return nil }

        let bounds = page.bounds(for: .mediaBox)
        guard bounds.width > 0, bounds.height > 0 else { return nil }

        // Du repere ecran (y vers le bas) vers le repere PDF (y vers le haut).
        let cropPDF = CGRect(
            x: bounds.minX + crop.minX * bounds.width,
            y: bounds.maxY - (crop.minY + crop.height) * bounds.height,
            width: crop.width * bounds.width,
            height: crop.height * bounds.height
        )

        let scale = CGFloat(pixelWidth) / cropPDF.width
        let pixelHeight = Int((cropPDF.height * scale).rounded())
        guard pixelHeight > 0 else { return nil }

        guard let context = CGContext(
            data: nil, width: pixelWidth, height: pixelHeight,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }

        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -cropPDF.minX, y: -cropPDF.minY)
        page.draw(with: .mediaBox, to: context)

        return context.makeImage()
    }
}
