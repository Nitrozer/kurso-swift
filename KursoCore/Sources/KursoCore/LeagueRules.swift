import Foundation

/// La ligue du §9, et rien de plus.
///
/// Douze places, uniquement des amis ajoutes par l'utilisateur, les trois
/// premiers montent le dimanche 20:00, **personne ne descend jamais**. Cette
/// derniere regle n'est pas une douceur : une ligue qui fait descendre punit
/// la semaine ou on a ete malade, et transforme un jeu en dette. On monte,
/// ou on reste.
public enum LeagueRules {

    /// Les duretes de mine. Plus la mine est tendre, plus elle marque —
    /// c'est la seule metaphore de progression du jeu.
    public enum Grade: String, CaseIterable, Sendable, Codable {
        case hb = "HB"
        case b2 = "2B"
        case b4 = "4B"
        case b6 = "6B"

        public var label: String { rawValue }

        public var order: Int { Grade.allCases.firstIndex(of: self) ?? 0 }

        /// `nil` au sommet : la 6B est la mine la plus tendre, il n'y a rien
        /// apres. Y rester n'est pas un echec, c'est l'arrivee.
        public var next: Grade? {
            let index = order + 1
            return index < Grade.allCases.count ? Grade.allCases[index] : nil
        }

        public var blurb: String {
            switch self {
            case .hb: "La mine de depart. Elle tient, elle ne marque pas fort."
            case .b2: "Un peu plus tendre. Le trait commence a se voir."
            case .b4: "Elle marque franchement. On sait que tu es passe."
            case .b6: "La plus tendre. Rien au-dessus."
            }
        }
    }

    /// Douze, pas plus : au-dela, un classement cesse d'etre un groupe
    /// d'amis et devient un tableau.
    public static let capacity = 12

    /// Les trois premiers montent. Pas les cinq, pas la moitie.
    public static let promotedCount = 3

    public struct Standing: Sendable, Equatable, Identifiable, Codable {
        public var id: String
        public var name: String
        public var initial: String
        /// XP de la SEMAINE seulement, remis a zero le lundi 04:00 (§9).
        public var weeklyXP: Int
        public var isMe: Bool

        public init(id: String, name: String, initial: String = "", weeklyXP: Int = 0, isMe: Bool = false) {
            self.id = id
            self.name = name
            self.initial = initial.isEmpty ? String(name.prefix(1)).uppercased() : initial
            self.weeklyXP = weeklyXP
            self.isMe = isMe
        }
    }

    /// Le tableau tel qu'il s'affiche : le plus d'XP en haut, et jamais plus
    /// de douze lignes. A egalite on departage par le nom, pour que deux
    /// ouvertures de l'ecran ne donnent pas deux ordres differents.
    public static func table(_ standings: [Standing]) -> [Standing] {
        standings
            .sorted { left, right in
                if left.weeklyXP != right.weeklyXP { return left.weeklyXP > right.weeklyXP }
                return left.name.localizedCaseInsensitiveCompare(right.name) == .orderedAscending
            }
            .prefix(capacity)
            .map { $0 }
    }

    /// Le rang commence a 1, comme on le lit.
    public static func rank(of id: String, in standings: [Standing]) -> Int? {
        table(standings).firstIndex { $0.id == id }.map { $0 + 1 }
    }

    public static func isPromoted(rank: Int) -> Bool {
        rank >= 1 && rank <= promotedCount
    }

    /// Ce qui arrive a la fermeture. Jamais `.demoted` : le cas n'existe pas.
    public enum Outcome: Equatable, Sendable {
        case promoted(Grade)
        case stays
        case atTop
    }

    public static func outcome(grade: Grade, rank: Int) -> Outcome {
        guard isPromoted(rank: rank) else { return .stays }
        guard let next = grade.next else { return .atTop }
        return .promoted(next)
    }

    /// Le lundi 04:00 qui ouvre la semaine en cours. Quatre heures du matin et
    /// pas minuit : celui qui revise a 01:00 le lundi finit la semaine qu'il
    /// avait commencee, pas celle d'apres.
    public static func weekStart(for date: Date, calendar: Calendar = .current) -> Date {
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        components.weekday = 2 // lundi
        components.hour = 4
        components.minute = 0
        components.second = 0
        var monday = calendar.date(from: components) ?? date
        // Le lundi entre 00:00 et 04:00 appartient encore a la semaine d'avant.
        if monday > date {
            monday = calendar.date(byAdding: .day, value: -7, to: monday) ?? monday
        }
        return monday
    }

    public static func needsReset(weekStartedAt: Date, now: Date, calendar: Calendar = .current) -> Bool {
        weekStart(for: now, calendar: calendar) > weekStartedAt
    }

    /// La fermeture : le prochain dimanche 20:00, strictement apres `now`.
    public static func closes(after now: Date, calendar: Calendar = .current) -> Date {
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        components.weekday = 1 // dimanche
        components.hour = 20
        components.minute = 0
        components.second = 0
        var sunday = calendar.date(from: components) ?? now
        // Le dimanche est le premier jour de la semaine ISO au sens d'Apple :
        // celui de la semaine en cours tombe AVANT le lundi qui l'ouvre.
        while sunday <= now {
            sunday = calendar.date(byAdding: .day, value: 7, to: sunday) ?? sunday
        }
        return sunday
    }

    /// Ce qu'on lit sous le tableau. Jamais de menace, jamais de compte a
    /// rebours anxieux : on annonce ce qui peut arriver de bien.
    public static func summary(rank: Int?, grade: Grade, count: Int) -> String {
        guard let rank else { return "Ajoute des amis pour ouvrir ta ligue." }
        if count <= 1 { return "Tu es seul ici. Ajoute un ami pour que ça compte." }
        if isPromoted(rank: rank) {
            return grade.next == nil
                ? "Tu es dans les trois. Tu es déjà au sommet des mines."
                : "Tu es dans les trois. Dimanche 20:00, tu passes en \(grade.next!.label)."
        }
        let gap = rank - promotedCount
        return gap == 1
            ? "Une place te sépare des trois qui montent."
            : "\(gap) places te séparent des trois qui montent."
    }
}
