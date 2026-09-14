import Foundation
import SwiftData
import KursoModels

/// Depot d'un PDF de cours (§11, etape 2).
///
/// Une page Kurso par page du PDF : c'est ce qui permet d'annoter diapo par
/// diapo, et de rattacher chacune a sa matiere comme n'importe quelle page.
enum PDFImporter {

    /// Depose un PDF et cree une page par diapo RETENUE.
    ///
    /// - Parameter selected: les diapos a garder, ou `nil` pour tout prendre.
    ///   Un polycopie de 80 pages dont on ne suit que le chapitre 3 n'a aucune
    ///   raison de remplir le cahier de 77 pages qu'on n'ouvrira jamais.
    @MainActor
    static func importFile(
        at url: URL,
        course: Course?,
        selected: IndexSet? = nil,
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
        let all = 0..<max(stored.pageCount, 1)
        let kept = selected.map { chosen in all.filter(chosen.contains) } ?? Array(all)
        for index in kept {
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
