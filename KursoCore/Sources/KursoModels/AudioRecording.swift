import Foundation
import SwiftData

/// Correspondance entre un trait PencilKit et l'instant audio ou il a ete trace.
/// SwiftData ne stocke pas de tuples : on passe par un type Codable (§7).
public struct StrokeTimestamp: Codable, Hashable, Sendable {
    public var strokeID: UUID
    public var offsetSeconds: Double
    /// Centre du trait dans la page. Sans lui, toucher un mot ne saurait pas
    /// quel trait on vise : PencilKit ne donne aucune identite stable.
    public var anchorX: Double
    public var anchorY: Double

    public init(strokeID: UUID, offsetSeconds: Double,
                anchorX: Double = 0, anchorY: Double = 0) {
        self.strokeID = strokeID
        self.offsetSeconds = offsetSeconds
        self.anchorX = anchorX
        self.anchorY = anchorY
    }
}

/// AAC 32 kbps mono, ~15 Mo pour deux heures. Stocke hors CloudKit par defaut
/// pour ne pas saturer l'iCloud de l'utilisateur (§7).
@Model public final class AudioRecording {
    public var id: UUID = UUID()
    /// Nom de fichier local, relatif au conteneur de l'app.
    public var fileName: String = ""
    public var startedAt: Date = Date()
    public var durationSeconds: Double = 0
    public var strokeTimestamps: [StrokeTimestamp] = []
    /// L'audio reste local sauf choix explicite de l'utilisateur.
    public var isIncludedInSync: Bool = false

    public var page: Page?

    public init(fileName: String = "", startedAt: Date = Date()) {
        self.fileName = fileName
        self.startedAt = startedAt
    }
}
