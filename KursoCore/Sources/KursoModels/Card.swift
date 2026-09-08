import Foundation
import CoreGraphics
import SwiftData

public enum CardKind: String, Codable, Sendable {
    case frontBack
    case cloze
    case imageOcclusion
}

/// Un rectangle enregistrable par SwiftData.
public struct OcclusionBox: Codable, Hashable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x; self.y = y; self.width = width; self.height = height
    }
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
    /// Zone masquee, en fractions de la page.
    ///
    /// Stockee comme une structure a champs nommes, jamais comme un CGRect :
    /// celui-ci s'encode en tableau `[x, y, w, h]`, un conteneur non cle, et
    /// SwiftData en exige un cle — il plantait a l'enregistrement avec
    /// « Composite Coder only supports Keyed Container ».
    public var occlusion: OcclusionBox?
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

    /// Vue pratique sur `occlusion`, pour le code d'affichage.
    public var occlusionRect: CGRect? {
        get {
            occlusion.map { CGRect(x: $0.x, y: $0.y, width: $0.width, height: $0.height) }
        }
        set {
            occlusion = newValue.map {
                OcclusionBox(x: $0.minX, y: $0.minY, width: $0.width, height: $0.height)
            }
        }
    }

    public init(question: String = "", kind: CardKind = .frontBack, dueAt: Date = Date()) {
        self.question = question
        self.kindRaw = kind.rawValue
        self.dueAt = dueAt
    }
}
