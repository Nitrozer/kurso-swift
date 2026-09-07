import Foundation

/// SM-2 simplifie (§2). Trois reponses seulement, volontairement lisibles.
public enum SpacedRepetition {

    public enum Answer: Sendable {
        case knew        // je savais
        case almost      // a peu pres
        case failed      // je sechais
    }

    /// Etat de repetition d'une carte. Type valeur : le module ne connait pas
    /// SwiftData, l'app fait le pont depuis son `Card`.
    public struct State: Equatable, Sendable {
        /// En jours.
        public var interval: Int
        public var ease: Double
        public var lapses: Int

        public init(interval: Int = 0, ease: Double = SpacedRepetition.initialEase, lapses: Int = 0) {
            self.interval = interval
            self.ease = ease
            self.lapses = lapses
        }
    }

    public static let initialEase = 2.3
    public static let maxEase = 2.8
    public static let minEase = 1.3
    public static let maxInterval = 180
    /// Une carte due a 04:00 : personne ne revise a minuit, et la journee
    /// d'etude commence apres le reveil.
    public static let dueHour = 4
    /// Deux echecs cumules et la carte entre au carnet des rates.
    public static let mistakeBookThreshold = 2

    /// Applique une reponse et rend le nouvel etat.
    public static func apply(_ answer: Answer, to state: State) -> State {
        var next = state

        switch answer {
        case .knew:
            next.ease = min(maxEase, state.ease + 0.10)
            next.interval = grown(from: state.interval, by: next.ease)

        case .almost:
            next.ease = max(minEase, state.ease - 0.05)
            next.interval = grown(from: state.interval, by: 1.2)

        case .failed:
            next.ease = max(minEase, state.ease - 0.20)
            next.interval = 1
            next.lapses = state.lapses + 1
        }

        next.interval = min(next.interval, maxInterval)
        return next
    }

    /// Les deux premiers paliers sont fixes — 1 jour, puis 3 — avant que
    /// l'intervalle se mette a croitre. C'est ce que decrit le §2 : « 1 j, puis
    /// 3 j, puis interval × ease ».
    private static func grown(from interval: Int, by factor: Double) -> Int {
        switch interval {
        case 0:  1
        case 1:  3
        default: Int((Double(interval) * factor).rounded())
        }
    }

    /// Une carte entre au carnet des rates a deux echecs cumules.
    public static func isInMistakeBook(_ state: State) -> Bool {
        state.lapses >= mistakeBookThreshold
    }

    /// Date de prochaine revision : maintenant plus l'intervalle, ramene a 04:00.
    public static func dueDate(
        from state: State,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Date {
        let shifted = calendar.date(byAdding: .day, value: state.interval, to: now) ?? now
        return calendar.date(bySettingHour: dueHour, minute: 0, second: 0, of: shifted) ?? shifted
    }
}
