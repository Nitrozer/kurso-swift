import Foundation
import SwiftData

/// Un PDF depose par le prof (§11, etape 2).
///
/// Absent du §1, mais `Page.pdfAssetID` le suppose : il faut bien que quelque
/// chose porte le fichier et son nombre de pages.
///
/// Le fichier lui-meme reste hors CloudKit par defaut, comme l'audio du §7 :
/// un polycopie de 40 Mo saturerait l'iCloud de l'utilisateur pour un contenu
/// qu'il peut retelecharger depuis l'ENT.
@Model public final class PDFAsset {
    public var id: UUID = UUID()
    /// Nom du fichier dans le conteneur de l'app.
    public var fileName: String = ""
    /// Titre affiche, repris du nom d'origine.
    public var title: String = ""
    public var pageCount: Int = 0
    public var importedAt: Date = Date()

    public init(id: UUID = UUID(), fileName: String = "", title: String = "", pageCount: Int = 0) {
        self.id = id
        self.fileName = fileName
        self.title = title
        self.pageCount = pageCount
    }
}
