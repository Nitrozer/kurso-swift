import Foundation
import SwiftData

@Model public final class Season {
    public var id: UUID = UUID()
    public var name: String = ""
    public var startsAt: Date = Date()
    /// Pilote le mode partiel (§9).
    public var examDate: Date?
    public var closedAt: Date?

    // Releve fige a la cloture.
    public var finalAcquiredPercent: Double?
    public var finalPagesCount: Int?
    public var finalWritingHours: Double?
    /// Saisie facultative.
    public var grade: Double?

    @Relationship(inverse: \Course.season)
    public var courses: [Course]? = []

    public init(name: String = "", startsAt: Date = Date()) {
        self.name = name
        self.startsAt = startsAt
    }
}
