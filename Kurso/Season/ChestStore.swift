import Foundation
import SwiftData
import KursoCore
import KursoModels

/// Le passage de niveau et le coffre qui l'accompagne (§9).
///
/// Le calcul du contenu est dans `Chest` ; ici on ne fait que l'inscrire dans
/// l'etat de jeu, une seule fois par niveau.
enum ChestStore {

    struct Reward: Equatable {
        var level: Int
        var shavings: Int
        var cover: Shop.Cover?
    }

    /// Ce qu'il y a a feter : le niveau atteint, les coffres, l'XP du jour.
    struct Celebration: Equatable, Identifiable {
        var id: Int { level }
        var level: Int
        var rewards: [Reward]
        var freezes: Int
        var xpToday: Int

        var shavings: Int { rewards.reduce(0) { $0 + $1.shavings } }
        var covers: [Shop.Cover] { rewards.compactMap(\.cover) }
    }

    /// Ouvre les coffres dus et rend de quoi montrer le passage de niveau.
    ///
    /// Rend nil pendant le mode partiel : le §9 met le jeu en veille a
    /// l'approche d'un examen, sans animation de niveau. Les coffres ne sont
    /// pas perdus pour autant — `lastChestLevel` ne bouge pas, ils tomberont
    /// une fois l'examen passe.
    @MainActor
    static func claim(_ context: ModelContext, isExamMode: Bool) -> Celebration? {
        guard ExamMode.showsGame(isExamMode: isExamMode) else { return nil }

        let player = PlayerStore.current(context)
        let levels = Chest.pending(currentLevel: player.level, lastOpened: player.lastChestLevel)
        guard !levels.isEmpty else { return nil }

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

        let freezes = Chest.freezes(inReserve: player.freezesRemaining, chests: levels.count)
        player.freezesRemaining += freezes
        player.lastChestLevel = player.level

        // Le crayon se retaille (§9) : l'usure repart de zero, et le repere
        // suit les heures deja ecrites pour que la suivante compte juste.
        player.writingSecondsAtLevel = totalWritingSeconds(context)
        player.mineWear = 0

        try? context.save()

        return Celebration(
            level: player.level,
            rewards: rewards,
            freezes: freezes,
            xpToday: DailyActivityStore.today(context: context).xpEarned
        )
    }

    /// Les secondes stylet pose, toutes pages confondues.
    @MainActor
    static func totalWritingSeconds(_ context: ModelContext) -> Int {
        let pages = (try? context.fetch(FetchDescriptor<Page>())) ?? []
        return pages.reduce(0) { $0 + $1.writingSeconds }
    }
}
