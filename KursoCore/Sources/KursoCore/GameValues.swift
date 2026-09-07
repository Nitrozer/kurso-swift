import Foundation

/// Les valeurs de jeu (§9), au chiffre pres.
public enum GameValues {

    // MARK: Combo

    /// ×1 au depart, ×2 a 2 justes, ×3 a 4, ×4 a 7.
    public static func combo(forStreak streak: Int) -> Int {
        switch streak {
        case ..<2: 1
        case 2...3: 2
        case 4...6: 3
        default: 4
        }
    }

    /// Le combo d'une page sans aucune faute.
    public static let perfectPageCombo = 6

    // MARK: XP

    public static let xpPerCard = 15
    public static let xpPerWrittenPage = 30
    /// Une page compte quand elle a recu au moins dix minutes d'ecriture reelle.
    public static let writtenPageSeconds = 600

    /// Une carte juste rapporte 15 × combo, double pendant le sprint.
    public static func xpForCard(combo: Int, isSprint: Bool = false) -> Int {
        xpPerCard * combo * (isSprint ? 2 : 1)
    }

    // MARK: Niveaux

    /// Seuil cumule pour atteindre le niveau suivant : 50 × n.
    ///
    /// Lecture litterale du §9 — « niveau n → n+1 : 50 × n XP cumules ». Le
    /// niveau 2 s'atteint donc a 50 XP au total, le niveau 3 a 100.
    public static let xpPerLevel = 50

    public static func level(forTotalXP xp: Int) -> Int {
        max(1, xp / xpPerLevel + 1)
    }

    public static func xpToNextLevel(fromTotalXP xp: Int) -> Int {
        xpPerLevel - (xp % xpPerLevel)
    }

    // MARK: Gommes

    public static let maxGommes = 5
    /// +1 toutes les 4 h.
    public static let gommeRegenSeconds: TimeInterval = 4 * 3600

    /// Une erreur consomme une gomme — sauf en version complete, ou le
    /// compteur n'est plus decremente. Ecrire des notes n'en coute jamais.
    public static func gommesAfterMistake(_ remaining: Int, hasFullVersion: Bool) -> Int {
        hasFullVersion ? remaining : max(0, remaining - 1)
    }

    /// Regeneration depuis la derniere recharge, plafonnee a 5.
    ///
    /// Rend aussi la nouvelle date de reference : sans elle, le temps deja
    /// ecoule serait recompte a chaque appel et les gommes remonteraient seules.
    public static func regenerate(
        remaining: Int,
        since lastRegen: Date,
        now: Date = .now
    ) -> (remaining: Int, lastRegen: Date) {
        guard remaining < maxGommes else { return (remaining, now) }

        let elapsed = now.timeIntervalSince(lastRegen)
        guard elapsed >= gommeRegenSeconds else { return (remaining, lastRegen) }

        let earned = Int(elapsed / gommeRegenSeconds)
        let newValue = min(maxGommes, remaining + earned)
        let consumed = TimeInterval(earned) * gommeRegenSeconds
        return (newValue, newValue >= maxGommes ? now : lastRegen.addingTimeInterval(consumed))
    }

    // MARK: Copeaux

    public static let shavingsPerCard = 8
    public static let shavingsPerFinishedPage = 40
    public static let shavingsPerMasteredNode = 120

    // MARK: Mine de Gribou

    /// Dix heures d'ecriture usent la mine entierement.
    public static let mineWearSeconds: Double = 36_000

    public static func mineWear(writingSecondsSinceLevel: Int) -> Double {
        min(1, Double(max(0, writingSecondsSinceLevel)) / mineWearSeconds)
    }

    // MARK: Mode partiel

    /// Actif a quatorze jours de l'examen, vingt-et-un si la saison precedente
    /// s'est finie avec des pages rouges.
    public static func isExamMode(
        examDate: Date?,
        now: Date = .now,
        previousSeasonHadRedPages: Bool = false
    ) -> Bool {
        guard let examDate else { return false }
        let days = examDate.timeIntervalSince(now) / 86_400
        guard days >= 0 else { return false }
        return days <= (previousSeasonHadRedPages ? 21 : 14)
    }
}
