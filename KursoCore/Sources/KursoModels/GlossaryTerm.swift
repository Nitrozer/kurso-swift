import Foundation
import SwiftData

/// Terme du glossaire d'une matiere. La definition est extraite d'une ligne
/// ecrite par l'etudiant : elle n'est jamais generee (§12).
@Model public final class GlossaryTerm {
    public var id: UUID = UUID()
    public var term: String = ""
    public var definition: String = ""
    public var occurrences: Int = 0

    public var course: Course?

    public init(term: String = "", definition: String = "") {
        self.term = term
        self.definition = definition
    }
}
