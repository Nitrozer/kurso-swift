import Foundation
import SwiftData
import KursoCore
import KursoModels

/// Import de l'emploi du temps (§6).
///
/// Le fichier est telecharge puis analyse sur l'appareil. Rien de ce qu'il
/// contient n'est envoye ailleurs — c'est la meme regle que pour les notes.
enum TimetableImporter {

    enum ImportError: LocalizedError {
        case invalidURL
        case unreachable
        case notCalendar
        case empty

        var errorDescription: String? {
            switch self {
            case .invalidURL:  "Cette adresse n'est pas valide."
            case .unreachable: "Impossible de joindre cette adresse. Verifiez le lien et votre connexion."
            case .notCalendar: "Ce lien ne renvoie pas un calendrier. Copiez le lien d'export ICS de votre ENT."
            case .empty:       "Ce calendrier ne contient aucun cours."
            }
        }
    }

    struct Proposal: Identifiable, Equatable {
        var id: String { group.name }
        let group: CourseGrouping.Group
        var isAccepted: Bool = true
        /// Nom modifiable : l'intitule d'un ENT est rarement celui qu'on emploie.
        var name: String
    }

    /// Telecharge, analyse et regroupe. Ne touche pas encore a la base :
    /// l'etudiant valide d'abord (§6).
    static func preview(urlString: String) async throws -> (proposals: [Proposal], events: [ICSEvent]) {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        // Les ENT distribuent souvent le lien en webcal://
        let normalized = trimmed
            .replacingOccurrences(of: "webcal://", with: "https://")
        guard let url = URL(string: normalized), url.scheme?.hasPrefix("http") == true else {
            throw ImportError.invalidURL
        }

        let data: Data
        do {
            (data, _) = try await URLSession.shared.data(from: url)
        } catch {
            throw ImportError.unreachable
        }

        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1),
              text.contains("BEGIN:VCALENDAR") || text.contains("BEGIN:VEVENT") else {
            throw ImportError.notCalendar
        }

        let events = ICSParser.parse(text)
        guard !events.isEmpty else { throw ImportError.empty }

        let proposals = CourseGrouping.group(events).map {
            Proposal(group: $0, name: $0.name)
        }
        return (proposals, events)
    }

    /// Cree les matieres retenues et leurs creneaux.
    @MainActor
    static func commit(
        proposals: [Proposal],
        events: [ICSEvent],
        url: String,
        context: ModelContext
    ) {
        let accepted = proposals.filter(\.isAccepted)
        var courseByUID: [String: Course] = [:]

        // Reimporter ne doit pas dupliquer : on reprend la matiere existante
        // quand le nom correspond, sinon les pages deja ecrites se
        // retrouveraient rattachees a une matiere devenue orpheline.
        let existing = (try? context.fetch(FetchDescriptor<Course>())) ?? []
        var byName = Dictionary(existing.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })

        // Les anciens creneaux partent : ils decrivent un emploi du temps
        // qui n'a plus cours.
        for slot in (try? context.fetch(FetchDescriptor<TimeSlot>())) ?? [] { context.delete(slot) }
        for old in (try? context.fetch(FetchDescriptor<Timetable>())) ?? [] { context.delete(old) }

        for proposal in accepted {
            let name = proposal.name.trimmingCharacters(in: .whitespaces)
            let course = byName[name] ?? Course(name: name)
            course.icsUID = proposal.group.uids.first
            course.teacher = proposal.group.teacher
            if byName[name] == nil {
                context.insert(course)
                byName[name] = course
            }
            for uid in proposal.group.uids { courseByUID[uid] = course }
        }

        for event in events {
            guard let course = courseByUID[event.uid] else { continue }
            let slot = TimeSlot(icsUID: event.uid, summary: event.summary, start: event.start, end: event.end)
            slot.location = event.location
            slot.recurrenceRule = event.recurrenceRule
            slot.course = course
            context.insert(slot)
        }

        let timetable = Timetable(url: url)
        timetable.lastAttemptAt = .now
        timetable.lastSuccessAt = .now
        context.insert(timetable)

        try? context.save()
    }
}
