import Foundation

/// Un creneau lu dans un fichier ICS.
public struct ICSEvent: Equatable, Sendable {
    public var uid: String
    public var summary: String
    public var location: String?
    public var start: Date
    public var end: Date
    /// Regle de recurrence, conservee telle quelle.
    public var recurrenceRule: String?
}

/// Lecture d'un emploi du temps ICS (RFC 5545).
///
/// Analyse locale, rien n'est envoye (§6). On ne lit que six proprietes :
/// DTSTART, DTEND, SUMMARY, LOCATION, UID, RRULE. Tout le reste est ignore —
/// un export ADE ou Hyperplanning contient des dizaines de champs dont aucun
/// ne nous concerne.
public enum ICSParser {

    public static func parse(_ text: String, calendar: Calendar = .current) -> [ICSEvent] {
        let lines = unfold(text)
        var events: [ICSEvent] = []
        var current: [String: (value: String, params: [String: String])] = [:]
        var inEvent = false

        for line in lines {
            if line == "BEGIN:VEVENT" { inEvent = true; current = [:]; continue }
            if line == "END:VEVENT" {
                if let event = makeEvent(from: current, calendar: calendar) { events.append(event) }
                inEvent = false
                continue
            }
            guard inEvent, let parsed = splitProperty(line) else { continue }
            current[parsed.name] = (parsed.value, parsed.params)
        }
        return events
    }

    // MARK: Depliage

    /// RFC 5545 : une ligne peut continuer sur la suivante, qui commence alors
    /// par une espace ou une tabulation. Sans ce depliage, un intitule de cours
    /// long est tronque en plein milieu.
    static func unfold(_ text: String) -> [String] {
        var result: [String] = []
        for raw in text.replacingOccurrences(of: "\r\n", with: "\n").split(separator: "\n", omittingEmptySubsequences: false) {
            if let first = raw.first, first == " " || first == "\t" {
                if !result.isEmpty { result[result.count - 1] += raw.dropFirst() }
            } else {
                result.append(String(raw))
            }
        }
        return result
    }

    // MARK: Proprietes

    /// `DTSTART;TZID=Europe/Paris:20260915T101500` se lit en trois morceaux.
    static func splitProperty(_ line: String) -> (name: String, params: [String: String], value: String)? {
        guard let colon = line.firstIndex(of: ":") else { return nil }
        let head = String(line[line.startIndex..<colon])
        let value = String(line[line.index(after: colon)...])

        let pieces = head.split(separator: ";")
        guard let name = pieces.first.map(String.init)?.uppercased() else { return nil }

        var params: [String: String] = [:]
        for piece in pieces.dropFirst() {
            let kv = piece.split(separator: "=", maxSplits: 1)
            if kv.count == 2 { params[kv[0].uppercased()] = String(kv[1]) }
        }
        return (name, params, value)
    }

    /// Les valeurs TEXT echappent la virgule, le point-virgule et le saut de ligne.
    static func unescape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\N", with: "\n")
            .replacingOccurrences(of: "\\,", with: ",")
            .replacingOccurrences(of: #"\;"#, with: ";")
            .replacingOccurrences(of: "\\\\", with: "\\")
    }

    // MARK: Dates

    /// Trois formes existent : UTC suffixee Z, heure locale, et date seule.
    static func parseDate(_ value: String, params: [String: String], calendar: Calendar) -> Date? {
        let digits = value.filter { $0.isNumber || $0 == "T" || $0 == "Z" }
        var components = DateComponents()

        guard digits.count >= 8 else { return nil }
        let raw = digits.replacingOccurrences(of: "T", with: "").replacingOccurrences(of: "Z", with: "")
        guard raw.count >= 8,
              let year = Int(raw.prefix(4)),
              let month = Int(raw.dropFirst(4).prefix(2)),
              let day = Int(raw.dropFirst(6).prefix(2)) else { return nil }

        components.year = year; components.month = month; components.day = day

        if raw.count >= 14 {
            components.hour = Int(raw.dropFirst(8).prefix(2))
            components.minute = Int(raw.dropFirst(10).prefix(2))
            components.second = Int(raw.dropFirst(12).prefix(2))
        }

        var cal = calendar
        if value.hasSuffix("Z") {
            cal.timeZone = TimeZone(secondsFromGMT: 0)!
        } else if let tzid = params["TZID"], let zone = TimeZone(identifier: tzid) {
            cal.timeZone = zone
        }
        return cal.date(from: components)
    }

    private static func makeEvent(
        from fields: [String: (value: String, params: [String: String])],
        calendar: Calendar
    ) -> ICSEvent? {
        guard let summaryField = fields["SUMMARY"],
              let startField = fields["DTSTART"],
              let start = parseDate(startField.value, params: startField.params, calendar: calendar)
        else { return nil }

        // Un creneau sans DTEND dure une heure par defaut : mieux vaut un
        // creneau approximatif qu'un cours absent de l'emploi du temps.
        let end = fields["DTEND"]
            .flatMap { parseDate($0.value, params: $0.params, calendar: calendar) }
            ?? start.addingTimeInterval(3600)

        return ICSEvent(
            uid: fields["UID"].map { unescape($0.value) } ?? UUID().uuidString,
            summary: unescape(summaryField.value),
            location: fields["LOCATION"].map { unescape($0.value) }.flatMap { $0.isEmpty ? nil : $0 },
            start: start,
            end: end,
            recurrenceRule: fields["RRULE"]?.value
        )
    }
}
