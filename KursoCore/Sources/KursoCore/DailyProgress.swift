import Foundation

/// La serie et les quetes du jour (§9).
public enum DailyProgress {

    // MARK: Serie

    /// Met a jour la serie apres une session terminee.
    ///
    /// Une session de plus dans la meme journee ne rallonge rien : la serie
    /// compte les jours, pas les sessions.
    public static func streak(
        current: Int,
        lastSessionDay: Date?,
        today: Date,
        calendar: Calendar = .current
    ) -> Int {
        let day = calendar.startOfDay(for: today)
        guard let last = lastSessionDay.map({ calendar.startOfDay(for: $0) }) else { return 1 }

        if calendar.isDate(last, inSameDayAs: day) { return current }

        let gap = calendar.dateComponents([.day], from: last, to: day).day ?? 0
        // Un jour d'ecart continue la serie ; au-dela elle repart a 1, sauf gel.
        return gap == 1 ? current + 1 : 1
    }

    /// Un gel peut sauver une journee manquee — un seul, et seulement pour un
    /// trou d'une journee : geler une semaine d'absence viderait la serie de son sens.
    public static func canFreeze(gapInDays: Int, freezesRemaining: Int) -> Bool {
        gapInDays == 2 && freezesRemaining > 0
    }

    // MARK: Quetes

    public enum QuestKind: String, CaseIterable, Sendable {
        case writePage      // ecrire une page
        case reviewCards    // reviser des cartes
        case captureCard    // capturer une carte

        public var title: String {
            switch self {
            case .writePage:   "Écrire une page de cours"
            case .reviewCards: "Réviser 8 cartes"
            case .captureCard: "Capturer une carte"
            }
        }

        public var target: Int {
            switch self {
            case .writePage:   1
            case .reviewCards: 8
            case .captureCard: 1
            }
        }

        /// 30 a 50 XP selon l'effort demande (§9).
        public var xp: Int {
            switch self {
            case .writePage:   40
            case .reviewCards: 50
            case .captureCard: 30
            }
        }
    }

    /// Les trois quetes d'une journee. Toujours les memes trois : une routine
    /// se tient parce qu'elle est previsible, pas parce qu'elle surprend.
    public static let dailyQuests = QuestKind.allCases
}
