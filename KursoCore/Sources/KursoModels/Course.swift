import Foundation
import SwiftData

@Model public final class Course {
    public var id: UUID = UUID()
    public var name: String = ""
    /// "blue" | "green" | "pink" | "yellow" | "grey"
    public var colorToken: String = "blue"
    /// Motif de couverture. « plain » par defaut : un cahier a toujours une
    /// couverture, meme sans avoir depense un copeau.
    public var coverStyle: String = "plain"
    /// Identifiant de la serie d'evenements ICS.
    public var icsUID: String?
    public var teacher: String?
    /// Non nil = matiere d'une saison archivee.
    public var archivedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \Page.course)
    public var pages: [Page]? = []

    @Relationship(deleteRule: .cascade, inverse: \GlossaryTerm.course)
    public var terms: [GlossaryTerm]? = []

    /// Inverse de Season.courses. Ajoute pour CloudKit : toute relation a son inverse.
    public var season: Season?

    @Relationship(deleteRule: .cascade, inverse: \TimeSlot.course)
    public var slots: [TimeSlot]? = []

    public init(name: String = "", colorToken: String = "blue") {
        self.name = name
        self.colorToken = colorToken
    }
}
