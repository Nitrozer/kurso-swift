import Foundation
import SwiftData

/// Tache detectee dans une page (§5).
///
/// Nommee `Assignment` et non `Task` : en Swift 6, un type nomme `Task` masque
/// `_Concurrency.Task` et casse toute utilisation de `Task { }` dans les memes
/// fichiers.
@Model public final class Assignment {
    public var id: UUID = UUID()
    public var title: String = ""
    public var dueAt: Date?
    /// Lignes de la note d'ou vient le devoir. Deux entiers, jamais un Range :
    /// un Range s'encode en tableau et SwiftData exige un conteneur a cles.
    public var sourceLineStart: Int?
    public var sourceLineEnd: Int?

    /// Vue pratique sur les deux bornes.
    public var sourceLineRange: Range<Int>? {
        get {
            guard let start = sourceLineStart, let end = sourceLineEnd, start < end else { return nil }
            return start..<end
        }
        set {
            sourceLineStart = newValue?.lowerBound
            sourceLineEnd = newValue?.upperBound
        }
    }
    /// true = issue d'une detection automatique. Une proposition n'est jamais
    /// transformee en tache sans validation de l'etudiant (§5).
    public var wasProposed: Bool = false
    public var isDone: Bool = false

    public var page: Page?

    public init(title: String = "", dueAt: Date? = nil, wasProposed: Bool = false) {
        self.title = title
        self.dueAt = dueAt
        self.wasProposed = wasProposed
    }
}
