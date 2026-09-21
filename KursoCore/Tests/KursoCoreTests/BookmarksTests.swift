import Testing
import Foundation
@testable import KursoCore

@Suite("Signets de cours")
struct BookmarksTests {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        return calendar
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 9, _ min: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    @Test("Une hauteur reste dans la page")
    func clamped() {
        #expect(Bookmarks.place(0.5) == 0.5)
        #expect(Bookmarks.place(-0.2) == 0)
        #expect(Bookmarks.place(1.8) == 1)
    }

    @Test("Le meme appui au meme endroit retrouve le signet deja pose")
    func toggles() {
        let heights = [0.1, 0.5, 0.9]
        #expect(Bookmarks.index(near: 0.51, among: heights) == 1)
        #expect(Bookmarks.index(near: 0.5, among: heights) == 1)
    }

    @Test("Un appui ailleurs ne retrouve rien")
    func addsElsewhere() {
        #expect(Bookmarks.index(near: 0.3, among: [0.1, 0.5, 0.9]) == nil)
    }

    @Test("Entre deux signets proches, c'est le plus proche qui repond")
    func nearestWins() {
        #expect(Bookmarks.index(near: 0.53, among: [0.5, 0.55], tolerance: 0.1) == 1)
        #expect(Bookmarks.index(near: 0.51, among: [0.5, 0.55], tolerance: 0.1) == 0)
    }

    @Test("Une page vide de signets ne repond rien")
    func empty() {
        #expect(Bookmarks.index(near: 0.5, among: []) == nil)
    }

    @Test("Le jour se dit en clair quand il est proche")
    func dayLabels() {
        let now = date(2026, 9, 21, 22)
        #expect(Bookmarks.day(date(2026, 9, 21, 9), now: now, calendar: calendar) == "aujourd'hui")
        #expect(Bookmarks.day(date(2026, 9, 20, 9), now: now, calendar: calendar) == "hier")
        #expect(Bookmarks.day(date(2026, 9, 17, 9), now: now, calendar: calendar) == "jeudi")
    }

    @Test("Au-dela de la semaine, on donne la date")
    func olderDay() {
        let now = date(2026, 9, 21, 22)
        let label = Bookmarks.day(date(2026, 9, 2, 9), now: now, calendar: calendar)
        #expect(label.contains("2"))
        #expect(!label.contains("il y a"))
    }

    @Test("L'extrait prend la premiere ligne qui porte quelque chose")
    func excerpt() {
        let text = "\n  \n21/09\nTransformee de Laplace et conditions initiales\n"
        #expect(Bookmarks.excerpt(from: text) == "Transformee de Laplace et conditions initiales")
    }

    @Test("Un extrait trop long se coupe a un mot entier")
    func excerptCut() {
        let text = String(repeating: "mot ", count: 40)
        let cut = Bookmarks.excerpt(from: text, limit: 20)
        #expect(cut.count <= 21)
        #expect(cut.hasSuffix("…"))
        #expect(!cut.contains("mo…"))
    }

    @Test("Un texte sans rien donne un extrait vide")
    func excerptEmpty() {
        #expect(Bookmarks.excerpt(from: "\n \na\n") == "")
    }

    @Test("Les signets se rangent par jour, le plus recent en tete")
    func grouped() {
        let dates = [
            date(2026, 9, 21, 9), date(2026, 9, 21, 14),
            date(2026, 9, 19, 11),
        ]
        let groups = Bookmarks.grouped(dates, date: { $0 }, calendar: calendar)
        #expect(groups.count == 2)
        #expect(groups.first?.items.first == date(2026, 9, 21, 14))
        #expect(groups.first?.items.count == 2)
        #expect(groups.last?.items == [date(2026, 9, 19, 11)])
    }
}
