import Foundation

/// La seance ou l'on n'etait pas la.
///
/// L'emploi du temps dit qu'il y avait cours ; le cahier est vide, et aucun
/// enregistrement n'a tourne. Kurso ne le reproche pas et ne le compte nulle
/// part : il propose une fois de demander ses notes a quelqu'un de la classe.
///
/// **Ce qui circule, et ce qui ne circule pas.** La demande passe par le
/// serveur : un nom de cours, une date, deux comptes. Les pages, elles, ne
/// passent jamais par la — celui qui accepte envoie un fichier directement,
/// d'appareil a appareil. Le §12 ne bouge pas : aucune donnee de cours sur un
/// serveur.
public enum MissedClass {

    /// On n'appelle pas un cours manque avant qu'il soit fini depuis deux
    /// heures : une page se ferme parfois dans le couloir, et une seance en
    /// cours n'est pas une seance ratee.
    public static let grace: TimeInterval = 2 * 3_600

    /// Au-dela d'une semaine, on ne propose plus rien. Des notes reclamees
    /// trois semaines plus tard n'arrivent jamais, et le rappel devient un
    /// reproche.
    public static let window: TimeInterval = 7 * 86_400

    /// Deux propositions, pas une liste de retard. Kurso ne tient pas de
    /// compte des absences.
    public static let maxSuggestions = 2

    public struct Slot: Sendable, Equatable, Identifiable {
        public var id: String
        public var courseName: String
        public var start: Date
        public var end: Date
        /// Une page ecrite pendant ou apres le creneau, meme vide de texte.
        /// Un enregistrement audio appartient toujours a une page : ce seul
        /// champ suffit donc a dire qu'on etait la.
        public var hasPage: Bool
        /// La demande a deja ete faite, ou ecartee. On ne repropose pas.
        public var settled: Bool

        public init(id: String, courseName: String, start: Date, end: Date,
                    hasPage: Bool = false, settled: Bool = false) {
            self.id = id
            self.courseName = courseName
            self.start = start
            self.end = end
            self.hasPage = hasPage
            self.settled = settled
        }
    }

    public struct Miss: Sendable, Equatable, Identifiable {
        public var id: String
        public var courseName: String
        public var start: Date

        public init(id: String, courseName: String, start: Date) {
            self.id = id
            self.courseName = courseName
            self.start = start
        }
    }

    /// Les seances qui valent une proposition, la plus recente en premier.
    ///
    /// Sans camarade a qui demander, on ne detecte rien : signaler un trou
    /// qu'on ne peut pas combler ne sert qu'a mettre mal a l'aise.
    public static func detect(slots: [Slot], hasClassmates: Bool = true, now: Date = Date()) -> [Miss] {
        guard hasClassmates else { return [] }
        return slots
            .filter { slot in
                guard !slot.settled, !slot.hasPage else { return false }
                let since = now.timeIntervalSince(slot.end)
                return since >= grace && since <= window
            }
            .sorted { $0.start > $1.start }
            .prefix(maxSuggestions)
            .map { Miss(id: $0.id, courseName: $0.courseName, start: $0.start) }
    }

    /// « Mardi, tu n'as rien écrit en Analyse. » Un constat, pas un rappel a
    /// l'ordre : ni « tu as manque », ni « absence ».
    public static func sentence(_ miss: Miss, now: Date = Date(), calendar: Calendar = .current) -> String {
        "\(day(miss.start, now: now, calendar: calendar).capitalizedFirst), tu n'as rien écrit en \(miss.courseName)."
    }

    public static func ask(_ miss: Miss, to name: String, now: Date = Date(), calendar: Calendar = .current) -> String {
        "Demander à \(name) ses notes \(of(miss.courseName)) de \(day(miss.start, now: now, calendar: calendar))"
    }

    /// Le texte que voit celui qui recoit la demande. Il nomme le cours et le
    /// jour, et rien d'autre : le serveur n'en sait pas plus.
    public static func invitation(from name: String, courseName: String, day: String) -> String {
        "\(name) te demande tes notes \(of(courseName)) de \(day)."
    }

    /// « de Analyse » ne se dit pas. Un nom de matiere commence souvent par
    /// une voyelle — Analyse, Anglais, Economie, Histoire — et l'elision se
    /// voit tout de suite quand elle manque.
    public static func of(_ courseName: String) -> String {
        let vowels: Set<Character> = ["a", "e", "i", "o", "u", "y", "h",
                                      "à", "â", "é", "è", "ê", "ë", "î", "ï", "ô", "ö", "û", "ù", "ü"]
        guard let first = courseName.lowercased().first, vowels.contains(first) else {
            return "de \(courseName)"
        }
        return "d'\(courseName)"
    }

    /// Ce qu'on explique au moment d'accepter. La phrase compte : c'est la
    /// seule occasion de dire ou vont les pages.
    public static let handoff =
        "Tes pages partent directement sur son appareil, par AirDrop. Elles ne passent par aucun serveur."

    /// « hier », « mardi », « mardi dernier ». Les noms sont ecrits ici plutot
    /// que tires d'un formateur : un test ne doit pas dependre de la langue
    /// reglee sur la machine.
    public static func day(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        let days = calendar.dateComponents([.day],
                                           from: calendar.startOfDay(for: date),
                                           to: calendar.startOfDay(for: now)).day ?? 0
        switch days {
        case 0: return "aujourd'hui"
        case 1: return "hier"
        case 2...6: return name(of: date, calendar: calendar)
        default: return "\(name(of: date, calendar: calendar)) dernier"
        }
    }

    private static func name(of date: Date, calendar: Calendar) -> String {
        let names = ["dimanche", "lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi"]
        let weekday = calendar.component(.weekday, from: date)
        return names[(weekday - 1 + names.count) % names.count]
    }
}

private extension String {
    var capitalizedFirst: String {
        guard let first else { return self }
        return String(first).uppercased() + dropFirst()
    }
}
