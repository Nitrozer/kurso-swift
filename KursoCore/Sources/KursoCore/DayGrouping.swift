import Foundation

/// Regroupement de pages par jour, pour l'affichage « pages datees ».
///
/// Generique sur l'element : ce module n'importe pas SwiftData (§11bis), donc il
/// ne connait pas `Page`. L'appelant fournit la date de chaque element.
public enum DayGrouping {

    public struct Day<Item>: Equatable where Item: Equatable {
        /// Minuit du jour, dans le calendrier fourni.
        public let start: Date
        public let items: [Item]
    }

    /// Rend les jours du plus recent au plus ancien, et dans chaque jour les
    /// elements du plus recent au plus ancien.
    ///
    /// L'ordre est impose ici plutot que laisse a l'appelant : une liste de notes
    /// se lit toujours en commencant par la derniere, et deux vues qui trient
    /// differemment donneraient deux listes incoherentes.
    public static func byDay<Item: Equatable>(
        _ items: [Item],
        calendar: Calendar = .current,
        date: (Item) -> Date
    ) -> [Day<Item>] {
        guard !items.isEmpty else { return [] }

        var buckets: [Date: [Item]] = [:]
        for item in items {
            let day = calendar.startOfDay(for: date(item))
            buckets[day, default: []].append(item)
        }

        return buckets
            .map { day, group in
                Day(start: day, items: group.sorted { date($0) > date($1) })
            }
            .sorted { $0.start > $1.start }
    }
}
