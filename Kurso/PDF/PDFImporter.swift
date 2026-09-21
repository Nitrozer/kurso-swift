import Foundation
import SwiftData
import KursoCore
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
        between bounds: (after: Double?, before: Double?) = (nil, nil),
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
        // Les diapos se repartissent entre les deux voisins : deposer un PDF
        // au milieu d'un cahier ne doit pas le renvoyer a la fin.
        let slots = Self.positions(count: kept.count, after: bounds.after, before: bounds.before)
        for (rank, index) in kept.enumerated() {
            let page = Page(
                title: stored.pageCount > 1 ? "\(stored.title) — \(index + 1)" : stored.title,
                createdAt: .now
            )
            // Le titre vient du fichier, pas de la reconnaissance : on ne veut
            // pas qu'une premiere ligne de diapo l'ecrase plus tard.
            page.titleWasEdited = true
            page.pdfAssetID = asset.id
            page.pdfPageIndex = index
            // Le texte de la diapo se lit maintenant, une fois : c'est lui qui
            // rendra la page trouvable.
            page.slideText = PDFStore.text(fileName: stored.fileName, pageIndex: index)
            page.slideTextAt = .now
            page.course = course
            page.position = slots[rank]
            context.insert(page)
            pages.append(page)
        }

        try? context.save()
        return pages
    }

    /// Des rangs regulierement espaces entre deux voisins.
    private static func positions(count: Int, after: Double?, before: Double?) -> [Double] {
        guard count > 0 else { return [] }
        guard let before else {
            let start = after ?? 0
            return (0..<count).map { start + Double($0 + 1) * PageOrdering.step }
        }
        let start = after ?? (before - PageOrdering.step)
        let gap = (before - start) / Double(count + 1)
        return (0..<count).map { start + gap * Double($0 + 1) }
    }
}
