import Foundation
import SwiftData
import KursoModels

/// Depot d'un PDF de cours (§11, etape 2).
///
/// Une page Kurso par page du PDF : c'est ce qui permet d'annoter diapo par
/// diapo, et de rattacher chacune a sa matiere comme n'importe quelle page.
enum PDFImporter {

    @MainActor
    static func importFile(
        at url: URL,
        course: Course?,
        context: ModelContext
    ) throws -> [Page] {
        let stored = try PDFStore.store(from: url)

        let asset = PDFAsset(
            fileName: stored.fileName,
            title: stored.title,
            pageCount: stored.pageCount
        )
        context.insert(asset)

        var pages: [Page] = []
        for index in 0..<max(stored.pageCount, 1) {
            let page = Page(
                title: stored.pageCount > 1 ? "\(stored.title) — \(index + 1)" : stored.title,
                createdAt: .now
            )
            // Le titre vient du fichier, pas de la reconnaissance : on ne veut
            // pas qu'une premiere ligne de diapo l'ecrase plus tard.
            page.titleWasEdited = true
            page.pdfAssetID = asset.id
            page.pdfPageIndex = index
            page.course = course
            context.insert(page)
            pages.append(page)
        }

        try? context.save()
        return pages
    }
}
