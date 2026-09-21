#if os(iOS)
import Foundation
import SwiftData
import KursoModels

/// Le texte des diapos deja importees.
///
/// Les PDF poses avant que la recherche sache les lire n'ont pas ce texte. Ne
/// rien faire pour eux laisserait la moitie d'un semestre introuvable — et
/// l'etudiant chercherait la cause dans ses notes, pas dans une version de
/// l'application.
enum SlideText {

    /// Combien de diapos on relit par passage.
    ///
    /// Un polycopie fait deux cents pages ; les relire toutes d'un coup
    /// figerait l'ecran a l'ouverture du cahier. On en prend un paquet a
    /// chaque fois, et le reste suit au passage suivant.
    static let batch = 40

    @MainActor
    static func backfill(_ context: ModelContext) {
        let waiting = FetchDescriptor<Page>(
            predicate: #Predicate { $0.pdfAssetID != nil && $0.slideTextAt == nil })
        guard let pages = try? context.fetch(waiting), !pages.isEmpty else { return }

        let assets = (try? context.fetch(FetchDescriptor<PDFAsset>())) ?? []
        var read = 0
        for page in pages {
            guard read < batch else { break }
            guard let assetID = page.pdfAssetID, let index = page.pdfPageIndex,
                  let file = assets.first(where: { $0.id == assetID })?.fileName else {
                // Le fichier a disparu : on marque quand meme, sinon on
                // reessaie a chaque lancement pour rien.
                page.slideTextAt = .now
                continue
            }
            page.slideText = PDFStore.text(fileName: file, pageIndex: index)
            page.slideTextAt = .now
            read += 1
        }
        try? context.save()
    }
}
#endif
