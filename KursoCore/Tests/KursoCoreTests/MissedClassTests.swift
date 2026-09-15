import Testing
import Foundation
@testable import KursoCore

@Suite("Cours manqué")
struct MissedClassTests {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        calendar.firstWeekday = 2
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    /// Mercredi 16 septembre 2026, 15:00.
    private var now: Date { date(2026, 9, 16, 15) }

    private func slot(_ name: String, daysAgo: Int, hour: Int = 10,
                      page: Bool = false, settled: Bool = false) -> MissedClass.Slot {
        let start = calendar.date(byAdding: .day, value: -daysAgo, to: date(2026, 9, 16, hour))!
        return MissedClass.Slot(id: "\(name)-\(daysAgo)", courseName: name,
                                start: start, end: start.addingTimeInterval(3_600),
                                hasPage: page, settled: settled)
    }

    @Test("Une seance sans page ni son est une seance manquee")
    func detects() {
        let found = MissedClass.detect(slots: [slot("Analyse", daysAgo: 1)], now: now)
        #expect(found.map(\.courseName) == ["Analyse"])
    }

    @Test("Une page ecrite, meme vide, suffit a dire qu'on etait la")
    func pageMeansPresent() {
        // L'audio n'a pas de champ a lui : un enregistrement appartient
        // toujours a une page, donc il est deja compte ici.
        #expect(MissedClass.detect(slots: [slot("Analyse", daysAgo: 1, page: true)], now: now).isEmpty)
    }

    @Test("On laisse deux heures avant de parler de seance manquee")
    func grace() {
        // Le cours vient de finir : la page se ferme parfois dans le couloir.
        let justOver = MissedClass.Slot(id: "x", courseName: "Analyse",
                                        start: now.addingTimeInterval(-5_400),
                                        end: now.addingTimeInterval(-1_800))
        #expect(MissedClass.detect(slots: [justOver], now: now).isEmpty)
        #expect(MissedClass.grace == 2 * 3_600)
    }

    @Test("Au-dela d'une semaine, on ne propose plus rien")
    func window() {
        #expect(MissedClass.detect(slots: [slot("Analyse", daysAgo: 8)], now: now).isEmpty)
        #expect(!MissedClass.detect(slots: [slot("Analyse", daysAgo: 6)], now: now).isEmpty)
    }

    @Test("Deux propositions au maximum, les plus recentes")
    func capped() {
        let slots = [slot("Analyse", daysAgo: 1), slot("Physique", daysAgo: 2),
                     slot("Droit", daysAgo: 3), slot("Anglais", daysAgo: 4)]
        let found = MissedClass.detect(slots: slots, now: now)
        #expect(found.count == MissedClass.maxSuggestions)
        #expect(found.map(\.courseName) == ["Analyse", "Physique"])
    }

    @Test("Une demande deja faite ne se repropose pas")
    func settled() {
        #expect(MissedClass.detect(slots: [slot("Analyse", daysAgo: 1, settled: true)], now: now).isEmpty)
    }

    @Test("Sans personne a qui demander, on ne signale rien")
    func silentWithoutClassmates() {
        // Montrer un trou qu'on ne peut pas combler ne sert qu'a mettre mal a l'aise.
        #expect(MissedClass.detect(slots: [slot("Analyse", daysAgo: 1)], hasClassmates: false, now: now).isEmpty)
    }

    @Test("Le jour se dit comme on le dirait")
    func dayNames() {
        #expect(MissedClass.day(date(2026, 9, 16, 10), now: now, calendar: calendar) == "aujourd'hui")
        #expect(MissedClass.day(date(2026, 9, 15, 10), now: now, calendar: calendar) == "hier")
        #expect(MissedClass.day(date(2026, 9, 14, 10), now: now, calendar: calendar) == "lundi")
        #expect(MissedClass.day(date(2026, 9, 11, 10), now: now, calendar: calendar) == "vendredi")
        #expect(MissedClass.day(date(2026, 9, 9, 10), now: now, calendar: calendar) == "mercredi dernier")
    }

    @Test("La phrase constate, elle ne reproche pas")
    func wording() {
        let miss = MissedClass.Miss(id: "x", courseName: "Analyse", start: date(2026, 9, 14, 10))
        let sentence = MissedClass.sentence(miss, now: now, calendar: calendar)
        #expect(sentence == "Lundi, tu n'as rien écrit en Analyse.")
        #expect(!sentence.localizedCaseInsensitiveContains("absen"))
        #expect(!sentence.localizedCaseInsensitiveContains("manqué"))
        #expect(MissedClass.ask(miss, to: "Léa", now: now, calendar: calendar)
                == "Demander à Léa ses notes d'Analyse de lundi")
    }

    @Test("« de Analyse » ne se dit pas")
    func elision() {
        #expect(MissedClass.of("Analyse") == "d'Analyse")
        #expect(MissedClass.of("Économie") == "d'Économie")
        #expect(MissedClass.of("Histoire") == "d'Histoire")
        #expect(MissedClass.of("Physique") == "de Physique")
        #expect(MissedClass.of("") == "de ")
    }

    @Test("Ce qui part au serveur est nomme, et ce n'est pas le cours")
    func handoffSaysWherePagesGo() {
        // §12 : aucune donnee de cours sur un serveur. La phrase le dit a
        // l'utilisateur au moment ou il accepte, pas dans des conditions.
        #expect(MissedClass.handoff.localizedCaseInsensitiveContains("airdrop"))
        #expect(MissedClass.handoff.localizedCaseInsensitiveContains("serveur"))
        #expect(MissedClass.invitation(from: "Thomas", courseName: "Analyse", day: "lundi")
                == "Thomas te demande tes notes d'Analyse de lundi.")
    }
}
