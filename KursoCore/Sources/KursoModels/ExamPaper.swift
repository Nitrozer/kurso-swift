import Foundation
import SwiftData

/// L'etat d'une page a la veille d'un partiel.
///
/// Photographiee AVANT l'examen : cet etat ne se reconstitue pas apres coup,
/// l'encre a continue de palir entre-temps. Sans cette photo, le retour sur
/// copie ne pourrait rien rapprocher.
@Model public final class ExamSnapshot {
    public var id: UUID = UUID()
    public var pageID: UUID = UUID()
    public var pageTitle: String = ""
    /// `Freshness.State.rawValue`.
    public var stateRaw: String = "brouillon"
    public var daysSinceReview: Int = 0
    public var takenAt: Date = Date()
    /// Le partiel concerne, pour ne photographier qu'une fois.
    public var examDate: Date = Date()

    public init() {}
}

/// Un rate saisi par l'etudiant, range dans la copie.
///
/// Struct a conteneur keye, pas un modele a part : SwiftData refuse les types
/// qui encodent dans un conteneur non keye, et un tableau de structures keyees
/// se stocke sans histoire.
public struct StoredMiss: Codable, Equatable, Hashable, Sendable {
    public var id: UUID
    public var label: String
    public var points: Double
    /// "exercise" ou "courseQuestion".
    public var kindRaw: String
    public var pageID: UUID?

    public init(id: UUID = UUID(), label: String = "", points: Double = 0,
                kindRaw: String = "exercise", pageID: UUID? = nil) {
        self.id = id
        self.label = label
        self.points = points
        self.kindRaw = kindRaw
        self.pageID = pageID
    }
}

/// Une copie rendue : la note, et ce qui a ete rate.
///
/// La saisie est facultative et ne quitte jamais l'appareil (§12).
@Model public final class ExamPaper {
    public var id: UUID = UUID()
    public var courseName: String = ""
    public var examDate: Date = Date()
    public var grade: Double = 0
    public var outOf: Double = 20
    public var misses: [StoredMiss] = []
    public var createdAt: Date = Date()

    public init() {}
}
