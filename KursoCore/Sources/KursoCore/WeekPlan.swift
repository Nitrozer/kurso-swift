import Foundation

/// La semaine : ce qui attend l'etudiant, pas seulement ce qui l'attend
/// aujourd'hui.
///
/// L'ecran du jour repond a « maintenant ». Il ne repond pas a « qu'est-ce
/// qui m'attend cette semaine », qui est la question du dimanche soir — celle
/// ou l'on decide quand reviser.
public enum WeekPlan {

    /// Les sept jours de la semaine qui contient cette date, du LUNDI au
    /// dimanche.
    ///
    /// Le lundi, quelle que soit la langue reglee sur l'appareil : une semaine
    /// scolaire commence le lundi, et un emploi du temps qui commencerait le
    /// dimanche se lirait de travers.
    public static func days(containing date: Date, calendar: Calendar = .current) -> [Date] {
        let day = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: day)
        // 1 = dimanche ; on recule jusqu'au lundi qui precede.
        let back = (weekday + 5) % 7
        guard let monday = calendar.date(byAdding: .day, value: -back, to: day) else { return [day] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: monday) }
    }

    /// Les heures a afficher.
    ///
    /// De la premiere a la derniere occupee, JAMAIS minuit a minuit : une
    /// grille de vingt-quatre heures consacre les trois quarts de l'ecran a
    /// des heures ou personne n'a cours.
    public static func hours(for slots: [(start: Date, end: Date)],
                             calendar: Calendar = .current) -> ClosedRange<Int> {
        let starts = slots.map { calendar.component(.hour, from: $0.start) }
        let ends = slots.map { slot -> Int in
            let hour = calendar.component(.hour, from: slot.end)
            let minute = calendar.component(.minute, from: slot.end)
            return minute > 0 ? hour + 1 : hour
        }
        guard let first = starts.min(), let last = ends.max() else { return 8...18 }
        // Une demi-journee au minimum : une semaine a un seul cours d'une
        // heure donnerait sinon une bande illisible.
        let low = max(0, min(first, 20))
        let high = min(24, max(last, low + 4))
        return low...high
    }

    /// La place d'un creneau dans sa colonne, en fractions de hauteur.
    public static func placement(_ slot: (start: Date, end: Date),
                                 in hours: ClosedRange<Int>,
                                 calendar: Calendar = .current) -> (y: Double, height: Double) {
        let span = Double(hours.upperBound - hours.lowerBound)
        guard span > 0 else { return (0, 1) }
        let from = Double(hours.lowerBound)
        let begin = decimal(slot.start, calendar) - from
        let finish = decimal(slot.end, calendar) - from
        let y = min(max(begin / span, 0), 1)
        // Jamais moins de quelques minutes de haut : un creneau d'un quart
        // d'heure doit rester attrapable.
        let height = min(max((finish - begin) / span, 0.02), 1 - y)
        return (y, height)
    }

    private static func decimal(_ date: Date, _ calendar: Calendar) -> Double {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return Double(parts.hour ?? 0) + Double(parts.minute ?? 0) / 60
    }

    /// Ce qui s'ecrit en haut : « 22 – 28 septembre », ou les deux mois quand
    /// la semaine les enjambe.
    public static func title(_ days: [Date], calendar: Calendar = .current) -> String {
        guard let first = days.first, let last = days.last else { return "" }
        let firstDay = calendar.component(.day, from: first)
        let lastDay = calendar.component(.day, from: last)
        let firstMonth = month(first, calendar)
        let lastMonth = month(last, calendar)
        return firstMonth == lastMonth
            ? "\(firstDay) – \(lastDay) \(lastMonth)"
            : "\(firstDay) \(firstMonth) – \(lastDay) \(lastMonth)"
    }

    /// Le nom d'un jour, abrege. Ecrit ici plutot que tire d'un formateur : un
    /// test ne doit pas dependre de la langue reglee sur la machine.
    public static func shortName(_ date: Date, calendar: Calendar = .current) -> String {
        let names = ["dim", "lun", "mar", "mer", "jeu", "ven", "sam"]
        return names[(calendar.component(.weekday, from: date) - 1 + names.count) % names.count]
    }

    private static func month(_ date: Date, _ calendar: Calendar) -> String {
        let names = ["janvier", "février", "mars", "avril", "mai", "juin", "juillet",
                     "août", "septembre", "octobre", "novembre", "décembre"]
        return names[(calendar.component(.month, from: date) - 1 + names.count) % names.count]
    }
}
