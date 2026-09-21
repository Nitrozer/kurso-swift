import Foundation
import SwiftData

/// L'etat d'une page a un moment donne.
///
/// Le filet du §1 : tant que la synchronisation iCloud est coupee, une gomme
/// qui derape sur une heure de cours ne se rattrape pas. On garde donc
/// quelques etats anterieurs du trace — quelques-uns seulement, car un trace
/// pese des centaines de kilo-octets.
///
/// Ce n'est PAS une sauvegarde : cela vit dans la meme base que la page, et
/// disparait avec elle.
@Model public final class PageSnapshot {
    public var id: UUID = UUID()
    public var takenAt: Date = Date()
    /// Hors de la base : un trace n'a rien a faire dans un enregistrement
    /// SwiftData (§1).
    @Attribute(.externalStorage) public var drawing: Data?
    /// Le nombre de traits, retenu pour savoir si la page a bouge sans avoir
    /// a relire le fichier a chaque geste.
    public var strokeCount: Int = 0

    public var page: Page?

    public init(drawing: Data? = nil, strokeCount: Int = 0, takenAt: Date = Date()) {
        self.drawing = drawing
        self.strokeCount = strokeCount
        self.takenAt = takenAt
    }
}
