import Foundation
import CoreGraphics
import SwiftData

public enum CardKind: String, Codable, Sendable {
    case frontBack
    case cloze
    case imageOcclusion
}

@Model public final class Card {
    public var id: UUID = UUID()
    public var kindRaw: String = CardKind.frontBack.rawValue
    public var question: String = ""
    /// Texte tape.
    public var answerText: String?
    /// PKDrawing : la ligne manuscrite, TELLE QUELLE. Jamais reecrite (§4).
    public var answerDrawing: Data?
    /// Pour .imageOcclusion sur une diapo.
    public var occlusionRect: CGRect?
    public var sourceLineRange: Range<Int>?

    // Etat de repetition espacee (§2).
    public var interval: Int = 0
    public var ease: Double = 2.3
    public var dueAt: Date = Date()
    public var lapses: Int = 0
    /// >= 2 echecs consecutifs.
    public var isInMistakeBook: Bool = false

    public var page: Page?

    /// CloudKit ne stocke pas d'enum directement : on persiste le rawValue.
    public var kind: CardKind {
        get { CardKind(rawValue: kindRaw) ?? .frontBack }
        set { kindRaw = newValue.rawValue }
    }

    public init(question: String = "", kind: CardKind = .frontBack, dueAt: Date = Date()) {
        self.question = question
        self.kindRaw = kind.rawValue
        self.dueAt = dueAt
    }
}
