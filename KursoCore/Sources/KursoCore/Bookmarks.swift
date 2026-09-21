import Foundation

/// Les signets poses pendant le cours.
///
/// En amphi, on n'annote pas : on ecrit vite, et le moment ou le professeur
/// insiste passe sans qu'on ait le temps d'ecrire pourquoi. Un signet est donc
/// un geste et rien d'autre — une marque a une hauteur de page, horodatee, que
/// l'on relit le soir. Le commentaire, s'il y en a un, s'ajoute apres coup.
public enum Bookmarks {

    /// A quelle distance deux signets se confondent, en fraction de page.
    ///
    /// Quatre centiemes : de quoi qu'un second appui au meme endroit retire
    /// le signet au lieu d'en empiler un deuxieme, sans qu'une marque posee
    /// en haut d'un paragraphe avale celle du paragraphe suivant.
    public static let tolerance: Double = 0.04

    /// La hauteur d'un signet, ramenee dans la page.
    public static func place(_ y: Double) -> Double {
        min(max(y, 0), 1)
    }

    /// Le signet deja pose a cette hauteur, s'il y en a un.
    ///
    /// C'est ce qui rend le geste reversible : le meme appui pose la marque,
    /// puis l'enleve.
    public static func index(near y: Double, among heights: [Double],
                             tolerance: Double = tolerance) -> Int? {
        var best: (index: Int, distance: Double)?
        for (index, height) in heights.enumerated() {
            let distance = abs(height - y)
            guard distance <= tolerance else { continue }
            if best == nil || distance < best!.distance {
                best = (index, distance)
            }
        }
        return best?.index
    }

    /// Le titre d'un jour dans la liste.
    ///
    /// Une date pleine ne dit rien a qui cherche « ce que j'ai marque ce
    /// matin » ; « aujourd'hui », si.
    public static func day(_ date: Date, now: Date = Date(),
                           calendar: Calendar = .current) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "aujourd'hui" }
        if calendar.isDateInYesterday(date) { return "hier" }

        let days = calendar.dateComponents([.day],
                                           from: calendar.startOfDay(for: date),
                                           to: calendar.startOfDay(for: now)).day ?? 0
        if days > 0 && days <= 6 { return weekday(date, calendar) }
        return date.formatted(.dateTime.day().month(.wide))
    }

    /// De quoi reconnaitre une page dans la liste quand elle n'a pas de titre.
    ///
    /// La premiere ligne qui porte des mots. Une page de cours commence
    /// souvent par la date ou un numero de chapitre : cela ne dit rien de ce
    /// qu'elle contient, on descend donc jusqu'a une ligne qui a des lettres.
    public static func excerpt(from text: String, limit: Int = 60) -> String {
        let line = text
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { $0.count > 2 && $0.contains(where: \.isLetter) } ?? ""
        guard line.count > limit else { return line }
        let cut = line.prefix(limit)
        // On coupe au dernier mot entier : un mot tranche se lit mal.
        if let space = cut.lastIndex(of: " "), cut.distance(from: cut.startIndex, to: space) > limit / 2 {
            return cut[..<space] + "…"
        }
        return cut + "…"
    }

    /// Les signets regroupes par jour, du plus recent au plus ancien.
    public static func grouped<Item>(_ items: [Item],
                                     date: (Item) -> Date,
                                     calendar: Calendar = .current) -> [(day: Date, items: [Item])] {
        var buckets: [Date: [Item]] = [:]
        for item in items {
            buckets[calendar.startOfDay(for: date(item)), default: []].append(item)
        }
        return buckets
            .map { (day: $0.key, items: $0.value.sorted { date($0) > date($1) }) }
            .sorted { $0.day > $1.day }
    }

    private static func weekday(_ date: Date, _ calendar: Calendar) -> String {
        // Ecrits ici plutot que tires d'un formateur : un test ne doit pas
        // dependre de la langue reglee sur la machine.
        let names = ["dimanche", "lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi"]
        return names[(calendar.component(.weekday, from: date) - 1 + names.count) % names.count]
    }
}
