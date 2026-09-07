import Testing
import Foundation
@testable import KursoCore

@Suite("Lecture ICS — §6")
struct ICSParserTests {

    var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }

    func date(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f.date(from: iso)!
    }

    let simple = """
    BEGIN:VCALENDAR
    BEGIN:VEVENT
    UID:abc-123
    SUMMARY:Algorithmique avancee
    LOCATION:Salle 204
    DTSTART:20260915T101500Z
    DTEND:20260915T121500Z
    END:VEVENT
    END:VCALENDAR
    """

    @Test("Un evenement simple est lu entierement")
    func simpleEvent() {
        let events = ICSParser.parse(simple, calendar: utc)
        #expect(events.count == 1)
        let e = events[0]
        #expect(e.uid == "abc-123")
        #expect(e.summary == "Algorithmique avancee")
        #expect(e.location == "Salle 204")
        #expect(e.start == date("2026-09-15T10:15:00Z"))
        #expect(e.end == date("2026-09-15T12:15:00Z"))
    }

    @Test("Une ligne repliee est recollee")
    func unfoldsContinuationLines() {
        // RFC 5545 : sans depliage, l'intitule serait tronque en plein milieu.
        let ics = """
        BEGIN:VEVENT
        UID:x
        SUMMARY:Algorithmique avancee et structures
          de donnees
        DTSTART:20260915T101500Z
        END:VEVENT
        """
        let e = ICSParser.parse(ics, calendar: utc)[0]
        #expect(e.summary == "Algorithmique avancee et structures de donnees")
    }

    @Test("Les parametres de propriete ne sont pas pris pour la valeur")
    func handlesPropertyParameters() {
        let ics = """
        BEGIN:VEVENT
        UID:x
        SUMMARY:Analyse
        DTSTART;TZID=Europe/Paris:20260915T101500
        END:VEVENT
        """
        let e = ICSParser.parse(ics, calendar: utc)[0]
        // 10:15 a Paris en septembre = 08:15 UTC.
        #expect(e.start == date("2026-09-15T08:15:00Z"))
    }

    @Test("Les echappements de texte sont resolus")
    func unescapesText() {
        let ics = #"""
        BEGIN:VEVENT
        UID:x
        SUMMARY:TD\, groupe 2\; salle B
        DTSTART:20260915T101500Z
        END:VEVENT
        """#
        let e = ICSParser.parse(ics, calendar: utc)[0]
        #expect(e.summary == "TD, groupe 2; salle B")
    }

    @Test("La regle de recurrence est conservee telle quelle")
    func keepsRecurrenceRule() {
        let ics = """
        BEGIN:VEVENT
        UID:x
        SUMMARY:Cours
        DTSTART:20260915T101500Z
        RRULE:FREQ=WEEKLY;COUNT=12
        END:VEVENT
        """
        #expect(ICSParser.parse(ics, calendar: utc)[0].recurrenceRule == "FREQ=WEEKLY;COUNT=12")
    }

    @Test("Sans DTEND, le creneau dure une heure")
    func defaultsToOneHour() {
        // Mieux vaut un creneau approximatif qu'un cours absent.
        let ics = """
        BEGIN:VEVENT
        UID:x
        SUMMARY:Cours
        DTSTART:20260915T101500Z
        END:VEVENT
        """
        let e = ICSParser.parse(ics, calendar: utc)[0]
        #expect(e.end.timeIntervalSince(e.start) == 3600)
    }

    @Test("Un evenement sans intitule ni date est ignore")
    func skipsIncompleteEvents() {
        let ics = """
        BEGIN:VEVENT
        UID:x
        END:VEVENT
        BEGIN:VEVENT
        UID:y
        SUMMARY:Valide
        DTSTART:20260915T101500Z
        END:VEVENT
        """
        let events = ICSParser.parse(ics, calendar: utc)
        #expect(events.map(\.summary) == ["Valide"])
    }

    @Test("Les proprietes hors des six retenues sont ignorees")
    func ignoresOtherProperties() {
        let ics = """
        BEGIN:VEVENT
        UID:x
        SUMMARY:Cours
        DESCRIPTION:Un long texte que personne ne lit
        ORGANIZER:mailto:ade@univ.fr
        SEQUENCE:3
        DTSTART:20260915T101500Z
        END:VEVENT
        """
        #expect(ICSParser.parse(ics, calendar: utc).count == 1)
    }

    @Test("Les retours chariot Windows ne cassent pas la lecture")
    func handlesCRLF() {
        let ics = simple.replacingOccurrences(of: "\n", with: "\r\n")
        #expect(ICSParser.parse(ics, calendar: utc).count == 1)
    }
}
