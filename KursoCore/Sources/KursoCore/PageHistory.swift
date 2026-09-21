import Foundation

/// L'historique d'une page : de quoi revenir en arriere apres coup.
///
/// L'annulation du canevas ne couvre que la session en cours, et la sauvegarde
/// est manuelle. Tant que la synchronisation iCloud est coupee, on ecrit donc
/// sans filet — et une gomme qui derape sur une heure de cours ne se rattrape
/// pas. Ces instantanes sont ce filet, rien de plus : ils ne remplacent pas
/// une sauvegarde, qui seule survit a la disparition de l'application.
public enum PageHistory {

    /// Combien d'instantanes par page.
    ///
    /// Six, pas trente : un trace pese des centaines de kilo-octets, et un
    /// semestre en compte des centaines. Au-dela, on protegerait le passe en
    /// remplissant l'appareil.
    public static let maximum = 6

    /// Deux instantanes ne se suivent pas de trop pres : sans ce delai, une
    /// heure d'ecriture en produirait des dizaines, tous semblables.
    public static let minimumGap: TimeInterval = 20 * 60

    /// Au-dela, c'est la sauvegarde qui repond, pas l'historique.
    public static let keepFor: TimeInterval = 14 * 86_400

    /// Faut-il garder l'etat actuel ?
    ///
    /// `changed` vient de l'appelant : un trace identique ne merite pas un
    /// instantane, meme une heure plus tard.
    public static func shouldKeep(last: Date?, now: Date = Date(), changed: Bool) -> Bool {
        guard changed else { return false }
        guard let last else { return true }
        return now.timeIntervalSince(last) >= minimumGap
    }

    /// Ceux qui ont trop vieilli.
    public static func expired(_ dates: [Date], now: Date = Date()) -> [Date] {
        dates.filter { now.timeIntervalSince($0) > keepFor }
    }

    /// Lequel sacrifier quand on depasse le compte.
    ///
    /// Celui dont la disparition laisse le plus petit trou : on garde ainsi
    /// l'histoire la plus ETALEE possible, plutot que six instantanes du meme
    /// quart d'heure. Ni le plus recent ni le plus ancien ne partent — l'un
    /// est ce a quoi l'on revient le plus souvent, l'autre est le point le
    /// plus loin qu'on puisse atteindre.
    public static func expendable(_ dates: [Date], limit: Int = maximum) -> Date? {
        let sorted = dates.sorted()
        guard sorted.count > limit, sorted.count >= 3 else { return nil }
        var worst: (date: Date, gap: TimeInterval)?
        for index in 1..<(sorted.count - 1) {
            let gap = sorted[index + 1].timeIntervalSince(sorted[index - 1])
            if worst == nil || gap < worst!.gap {
                worst = (sorted[index], gap)
            }
        }
        return worst?.date
    }

    /// Comment on nomme un instantane.
    ///
    /// Une date complete ne dit rien a qui cherche « avant que j'efface » ;
    /// une duree, si.
    public static func label(_ date: Date, now: Date = Date(),
                             calendar: Calendar = .current) -> String {
        let seconds = now.timeIntervalSince(date)
        if seconds < 90 { return "à l'instant" }
        if seconds < 3_600 { return "il y a \(Int(seconds / 60)) min" }

        let hour = date.formatted(.dateTime.hour().minute())
        if calendar.isDateInToday(date) {
            let hours = Int(seconds / 3_600)
            return hours < 6 ? "il y a \(hours) h" : "aujourd'hui \(hour)"
        }
        if calendar.isDateInYesterday(date) { return "hier \(hour)" }

        let days = calendar.dateComponents([.day],
                                           from: calendar.startOfDay(for: date),
                                           to: calendar.startOfDay(for: now)).day ?? 0
        return days <= 6 ? "\(weekday(date, calendar)) \(hour)"
                         : date.formatted(.dateTime.day().month().hour().minute())
    }

    private static func weekday(_ date: Date, _ calendar: Calendar) -> String {
        // Ecrits ici plutot que tires d'un formateur : un test ne doit pas
        // dependre de la langue reglee sur la machine.
        let names = ["dimanche", "lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi"]
        return names[(calendar.component(.weekday, from: date) - 1 + names.count) % names.count]
    }
}
