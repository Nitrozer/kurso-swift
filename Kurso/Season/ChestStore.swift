import Foundation
import SwiftData
import KursoCore
import KursoModels

/// L'ouverture des coffres de passage de niveau (§9).
///
/// Le calcul du contenu est dans `Chest` ; ici on ne fait que l'inscrire dans
/// l'etat de jeu, une seule fois par niveau.
enum ChestStore {

    struct Reward: Equatable {
        var level: Int
        var shavings: Int
        var cover: Shop.Cover?
    }

    /// Ouvre les coffres dus et rend ce qu'ils contenaient.
    ///
    /// Rend un tableau vide pendant le mode partiel : le §9 met le jeu en
    /// veille a l'approche d'un examen. Les coffres ne sont pas perdus pour
    /// autant — `lastChestLevel` ne bouge pas, ils tomberont apres.
    @MainActor
    static func claim(_ context: ModelContext, isExamMode: Bool) -> [Reward] {
        guard ExamMode.showsGame(isExamMode: isExamMode) else { return [] }

        let player = PlayerStore.current(context)
        let levels = Chest.pending(currentLevel: player.level, lastOpened: player.lastChestLevel)
        guard !levels.isEmpty else { return [] }

        var owned = Set(player.ownedCovers)
        var rewards: [Reward] = []

        for level in levels {
            let shavings = Chest.shavings(forLevel: level)
            let cover = Chest.cover(forLevel: level, owned: owned)
            player.shavings += shavings
            if let cover {
                owned.insert(cover.rawValue)
                player.ownedCovers.append(cover.rawValue)
            }
            rewards.append(Reward(level: level, shavings: shavings, cover: cover))
        }

        player.lastChestLevel = player.level
        try? context.save()
        return rewards
    }
}
