import Foundation

/// Quand a-t-on le droit d'ecrire un trace par-dessus celui deja enregistre ?
///
/// Une page perdue est le pire defaut possible de cette application. Trois
/// signalements ont eu la meme cause : un enregistrement declenche par un
/// demontage de vue, portant un trace vide ou perime, ecrasant du travail.
///
/// La regle : un geste de l'utilisateur fait foi, toujours. Un enregistrement
/// automatique, lui, n'a pas le droit de vider une page.
public enum DrawingSaveGuard {
    public enum Origin: Sendable, Equatable {
        /// L'utilisateur vient de lever son stylet : ce qu'il voit fait foi,
        /// y compris s'il a tout efface.
        case gesture
        /// La vue se demonte ou se ferme. Aucun geste derriere.
        case teardown
    }

    public static func shouldWrite(incomingStrokes: Int,
                                   storedStrokes: Int,
                                   origin: Origin) -> Bool {
        switch origin {
        case .gesture:
            true
        case .teardown:
            // Vider une page ne s'obtient que par la gomme, jamais par un
            // effet de bord de navigation.
            !(incomingStrokes == 0 && storedStrokes > 0)
        }
    }
}
