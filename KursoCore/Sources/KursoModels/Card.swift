import Foundation
import CoreGraphics
import SwiftData

public enum CardKind: String, Codable, Sendable {
    case frontBack
    case cloze
    case imageOcclusion
}

/// Un rectangle enregistrable par SwiftData.
public struct StoredRect: Codable, Hashable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x; self.y = y; self.width = width; self.height = height
    }
}

/// Ancien nom, garde pour ne rien casser.
public typealias OcclusionBox = StoredRect

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
    public var occlusion: StoredRect?
    /// Lignes du markdown d'ou vient la carte.
    ///
    /// Deux entiers, jamais un Range : comme CGRect, un Range s'encode en
    /// tableau, et SwiftData exige un conteneur a cles.
    public var sourceLineStart: Int?
    public var sourceLineEnd: Int?

    /// Image de la diapo dont la carte est tiree, pour pouvoir la reviser
    /// sans rouvrir le PDF.
    @Attribute(.externalStorage) public var imageData: Data?

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

    /// Vue pratique sur `occlusion`, pour le code d'affichage.
    public var occlusionRect: CGRect? {
        get {
            occlusion.map { CGRect(x: $0.x, y: $0.y, width: $0.width, height: $0.height) }
        }
        set {
            occlusion = newValue.map {
                StoredRect(x: $0.minX, y: $0.minY, width: $0.width, height: $0.height)
            }
        }
    }

    public init(question: String = "", kind: CardKind = .frontBack, dueAt: Date = Date()) {
        self.question = question
        self.kindRaw = kind.rawValue
        self.dueAt = dueAt
    }
}
