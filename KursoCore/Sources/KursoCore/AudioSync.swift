import Foundation
import CoreGraphics

/// L'audio colle a l'ecriture (§7).
///
/// Pendant l'enregistrement, chaque trait termine retient l'instant ou il a
/// ete trace. A la lecture, toucher un mot cherche le trait le plus proche et
/// remonte de deux secondes : on veut le debut de la phrase du prof, pas son
/// milieu.
public enum AudioSync {

    /// De combien on remonte avant l'instant du trait.
    public static let leadSeconds: Double = 2

    /// Un trait et l'instant ou il a ete ecrit.
    public struct Mark: Equatable, Sendable {
        public let strokeID: UUID
        public let offsetSeconds: Double
        /// Le centre du trait, dans le repere de la page.
        public let anchor: CGPoint

        public init(strokeID: UUID, offsetSeconds: Double, anchor: CGPoint) {
            self.strokeID = strokeID
            self.offsetSeconds = offsetSeconds
            self.anchor = anchor
        }
    }

    /// Ou placer la lecture pour ce trait.
    public static func playbackTime(for mark: Mark) -> Double {
        max(0, mark.offsetSeconds - leadSeconds)
    }

    /// Le trait le plus proche du point touche, s'il est assez pres.
    ///
    /// Le rayon evite de jouer n'importe quoi quand on touche une zone vide :
    /// mieux vaut ne rien faire que remonter au hasard dans le cours.
    public static func nearest(to point: CGPoint,
                               among marks: [Mark],
                               within radius: CGFloat) -> Mark? {
        var best: (mark: Mark, distance: CGFloat)?
        for mark in marks {
            let dx = mark.anchor.x - point.x
            let dy = mark.anchor.y - point.y
            let distance = (dx * dx + dy * dy).squareRoot()
            guard distance <= radius else { continue }
            if best == nil || distance < best!.distance {
                best = (mark, distance)
            }
        }
        return best?.mark
    }

    /// Duree lisible, pour l'afficher pendant l'enregistrement.
    public static func clock(_ seconds: Double) -> String {
        let total = Int(max(0, seconds))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
