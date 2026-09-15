import Foundation

/// Le releve de fin de semestre (§11, etape 4).
///
/// Il se calcule ici, loin de SwiftData et de SwiftUI, parce qu'il est fige a
/// la cloture : une valeur fausse ne se rattrape plus une fois le semestre
/// archive. Tout est recalcule depuis les pages, rien n'est lu d'un compteur
/// qui aurait pu deriver.
public enum SeasonReport {

    /// Une page, reduite a ce que le releve regarde.
    public struct PageInput: Equatable, Sendable {
        public let writingSeconds: Int
        public let cards: [Freshness.CardState]
        /// Total des rates sur les cartes de la page, pour la rarete.
        public let lapses: Int

        public init(writingSeconds: Int, cards: [Freshness.CardState], lapses: Int = 0) {
            self.writingSeconds = writingSeconds
            self.cards = cards
            self.lapses = lapses
        }
    }

    public struct Report: Equatable, Sendable {
        /// Moyenne de fraicheur de la carte, 0 a 1. Voir `acquiredPercent`.
        public var acquired: Double
        public var pages: Int
        public var writingHours: Double
        public var cardsReviewed: Int
        public var longestStreak: Int
        public var goldFiches: Int
        public var totalFiches: Int
        /// Un taille-crayon par niveau franchi (§9).
        public var mineChanges: Int
        /// L'etat de chaque noeud, dans l'ordre des pages — les pastilles.
        public var states: [Freshness.State]

        public var acquiredPercent: Int { Int((acquired * 100).rounded()) }

        public func count(_ state: Freshness.State) -> Int {
            states.filter { $0 == state }.count
        }
    }

    /// Le releve d'un semestre.
    ///
    /// `acquired` est la **moyenne de fraicheur** des noeuds qui portent des
    /// cartes, pas la part de noeuds verts : la maquette annonce 82 % avec 14
    /// noeuds acquis sur 24, donc ce n'est pas un simple ratio. Un noeud a
    /// demi pali compte pour ce qu'il vaut, ce qui est aussi la lecture juste
    /// de « l'etat de ta memoire le jour ou on t'interroge ».
    ///
    /// Les brouillons — pages sans carte — comptent dans les pages ecrites
    /// mais pas dans la carte : on ne reproche pas de ne pas avoir fini (§3).
    public static func make(
        pages: [PageInput],
        cardsReviewed: Int,
        longestStreak: Int,
        level: Int,
        now: Date = .now
    ) -> Report {
        let states = pages.map { Freshness.state(cards: $0.cards, now: now) }
        let scored = pages.filter { !$0.cards.isEmpty }
        let acquired = scored.isEmpty
            ? 0
            : scored.map { Freshness.compute(cards: $0.cards, now: now) }.reduce(0, +) / Double(scored.count)

        let rarities = pages.map { page in
            Fiche.rarity(
                cardCount: page.cards.count,
                acquired: page.cards.filter { Fiche.isAcquired(interval: $0.interval, dueAt: $0.dueAt, now: now) }.count,
                lapses: page.lapses
            )
        }

        return Report(
            acquired: acquired,
            pages: pages.count,
            writingHours: (Double(pages.reduce(0) { $0 + $1.writingSeconds }) / 3_600 * 10).rounded() / 10,
            cardsReviewed: max(0, cardsReviewed),
            longestStreak: max(0, longestStreak),
            goldFiches: rarities.filter { $0 == .gold }.count,
            totalFiches: rarities.filter { $0 != .locked }.count,
            mineChanges: max(0, level - 1),
            states: states
        )
    }

    /// Le nom du semestre suivant.
    ///
    /// On incremente le dernier nombre du nom plutot que de demander a
    /// l'utilisateur : « Semestre 5 » suit « Semestre 4 » sans qu'on ait a
    /// poser la question. Un nom sans chiffre est repris tel quel, suffixe.
    public static func nextName(after name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "Nouveau semestre" }

        // Le dernier groupe de chiffres, et lui seul : « Semestre 2024-1 »
        // doit passer a « Semestre 2024-2 », pas a « Semestre 2025-1 ».
        guard let range = trimmed.range(of: "[0-9]+(?!.*[0-9])", options: .regularExpression),
              let value = Int(trimmed[range]) else {
            return trimmed + " (suite)"
        }
        return trimmed.replacingCharacters(in: range, with: String(value + 1))
    }

    /// Le releve en texte, pour le partage.
    ///
    /// Des chiffres, jamais de contenu de cours : ce qu'on partage peut finir
    /// n'importe ou, et le §12 garde les notes sur l'appareil.
    public static func shareText(_ report: Report, seasonName: String) -> String {
        let hours = report.writingHours.formatted(.number.precision(.fractionLength(0...1)))
        var lines = ["\(seasonName) — relevé Kurso", ""]
        lines.append("Carte acquise : \(report.acquiredPercent) %")
        lines.append("Pages écrites : \(report.pages)")
        lines.append("Heures d'écriture : \(hours) h")
        lines.append("Cartes revues : \(report.cardsReviewed)")
        lines.append("Plus longue série : \(report.longestStreak) jours")
        lines.append("Fiches or : \(report.goldFiches) sur \(report.totalFiches)")
        return lines.joined(separator: "\n")
    }

    /// La phrase d'ouverture du releve.
    public static func headline(_ report: Report) -> String {
        "Tu as fini le semestre avec \(report.acquiredPercent) % de ta carte acquise."
    }
}
