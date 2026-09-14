import Foundation
import SwiftData
import KursoCore
import KursoModels

/// Acces a l'etat de jeu, unique.
enum PlayerStore {

    @MainActor
    static func current(_ context: ModelContext) -> PlayerState {
        if let existing = try? context.fetch(FetchDescriptor<PlayerState>()).first {
            return existing
        }
        let made = PlayerState()
        context.insert(made)
        try? context.save()
        return made
    }

    /// Verse des copeaux. Ils n'achetent que de l'apparence (§9) : les verser
    /// ne fait donc progresser personne, et on peut le faire sans ceremonie.
    @MainActor
    static func award(shavings: Int, context: ModelContext) {
        guard shavings > 0 else { return }
        current(context).shavings += shavings
        try? context.save()
    }
}
