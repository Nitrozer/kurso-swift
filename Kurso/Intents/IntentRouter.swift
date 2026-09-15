import Foundation
import Observation

/// Ce qu'un intent demande a l'interface de faire au prochain affichage.
///
/// Un intent ne peut pas manipuler la vue directement : il depose une
/// intention ici, et l'application la consomme quand elle s'ouvre.
@MainActor
@Observable
final class IntentRouter {
    static let shared = IntentRouter()

    var pendingTab: RailTab?
    /// Le cahier a ouvrir, par identifiant — jamais par contenu.
    var pendingCourseID: UUID?

    private init() {}
}
