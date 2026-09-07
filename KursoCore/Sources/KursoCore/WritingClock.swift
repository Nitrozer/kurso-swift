import Foundation

/// Mesure le temps d'ecriture reel d'une page : stylet pose, pas temps d'ecran.
///
/// §1 de PASSATION.md : « `writingSeconds` est mesure au stylet pose, pas au temps
/// d'ecran [...] Une page ouverte sans ecrire ne compte pas. » C'est cette valeur
/// qui pilotera `mineWear` (§9), donc une page laissee ouverte pendant deux heures
/// sans un trait doit rendre zero.
///
/// Type valeur, sans dependance : il vit dans le module pur (§11bis) et se teste
/// sans lancer l'app ni instancier de `ModelContainer`.
public struct WritingClock: Equatable, Sendable {

    /// Duree maximale retenue pour une seule periode d'ecriture continue.
    ///
    /// Les evenements de debut et de fin viennent du delegue PencilKit. Si l'app
    /// passe en arriere-plan stylet pose, ou si un evenement de fin se perd, la
    /// periode resterait ouverte indefiniment et gonflerait le total. Au-dela de
    /// ce seuil on considere l'evenement perdu plutot que d'accumuler une valeur
    /// fausse : mieux vaut sous-compter que mentir sur le temps de travail.
    public static let maxSpanSeconds: TimeInterval = 30 * 60

    private var accumulated: TimeInterval
    private var startedAt: Date?

    public init(accumulatedSeconds: Int = 0) {
        self.accumulated = TimeInterval(max(0, accumulatedSeconds))
        self.startedAt = nil
    }

    public var isWriting: Bool { startedAt != nil }

    /// Le stylet touche la surface. Un second appel sans `end` est ignore :
    /// PencilKit peut emettre des debuts consecutifs, et les compter deux fois
    /// doublerait le temps.
    public mutating func begin(at date: Date) {
        guard startedAt == nil else { return }
        startedAt = date
    }

    /// Le stylet quitte la surface. Un `end` sans `begin` correspondant ne change
    /// rien plutot que de lever une erreur : le delegue n'est pas sous notre controle.
    public mutating func end(at date: Date) {
        guard let start = startedAt else { return }
        accumulated += Self.clampedSpan(from: start, to: date)
        startedAt = nil
    }

    /// Total en secondes, periode en cours comprise.
    public func seconds(now: Date) -> Int {
        var total = accumulated
        if let start = startedAt {
            total += Self.clampedSpan(from: start, to: now)
        }
        return Int(total.rounded())
    }

    /// Une periode negative (horloge systeme reculee) vaut zero.
    private static func clampedSpan(from start: Date, to end: Date) -> TimeInterval {
        let span = end.timeIntervalSince(start)
        guard span > 0 else { return 0 }
        return min(span, maxSpanSeconds)
    }
}
