import Foundation
import SwiftData

/// Regroupement suggere. Tant que `isConfirmedByUser` est faux, il s'affiche
/// en pointilles : c'est une proposition, pas un dossier (§12 interdit les dossiers).
@Model public final class Chapter {
    public var id: UUID = UUID()
    public var name: String = ""
    public var isConfirmedByUser: Bool = false

    @Relationship(inverse: \Page.chapter)
    public var pages: [Page]? = []

    public init(name: String = "", isConfirmedByUser: Bool = false) {
        self.name = name
        self.isConfirmedByUser = isConfirmedByUser
    }
}
