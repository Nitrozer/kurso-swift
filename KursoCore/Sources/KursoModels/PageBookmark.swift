import Foundation
import SwiftData

/// Un signet pose sur une page pendant le cours.
///
/// Le professeur insiste, et il faut deux secondes pour le noter — pas plus :
/// pendant ce temps la phrase suivante est deja passee. Un signet n'est donc
/// qu'une hauteur dans la page et une heure. Le commentaire vient le soir,
/// quand on relit la liste.
@Model public final class PageBookmark {
    public var id: UUID = UUID()
    public var createdAt: Date = Date()
    /// Ou dans la page, de 0 en haut a 1 en bas. Une proportion et non des
    /// points : la page se lit a toutes les tailles d'ecran.
    public var height: Double = 0
    /// Ajoute apres coup, souvent vide.
    public var note: String = ""

    public var page: Page?

    public init(height: Double, note: String = "", createdAt: Date = Date()) {
        self.height = height
        self.note = note
        self.createdAt = createdAt
    }
}
