#if DEBUG
import Foundation
import SwiftData
import PencilKit
import KursoModels

/// Donnees de demonstration, uniquement en debug et uniquement sur demande.
///
/// Declenchees par l'argument de lancement `-seedDemoData`, jamais au demarrage
/// normal : elles servent a voir les ecrans pleins pendant le developpement,
/// pas a fabriquer du faux contenu chez l'utilisateur.
enum DebugSeed {

    static var isRequested: Bool {
        ProcessInfo.processInfo.arguments.contains("-seedDemoData")
    }

    @MainActor
    static func run(context: ModelContext) {
        guard isRequested else { return }
        // Idempotent : relancer avec le drapeau ne duplique rien.
        let existing = (try? context.fetch(FetchDescriptor<Course>())) ?? []
        guard existing.isEmpty else { return }

        let course = Course(name: "Automatique", colorToken: "blue")
        course.teacher = "GIMMIG Matthieu"
        context.insert(course)

        let page = Page(title: "Correcteur PID", createdAt: .now)
        page.course = course
        page.writingSeconds = 1_500
        page.recognizedText = "DM d'automatique à rendre pour le 15 octobre\nle terme intégral annule l'erreur statique"
        page.drawing = handwriting().dataRepresentation()
        context.insert(page)

        for (question, offsetDays) in [("Que fait le terme intégral ?", 0), ("Effet du terme dérivé ?", 0), ("Formule du dépassement ?", -1)] {
            let card = Card(question: question, kind: .frontBack,
                            dueAt: Date().addingTimeInterval(Double(offsetDays) * 86_400))
            card.answerDrawing = handwriting().dataRepresentation()
            card.page = page
            context.insert(card)
        }

        // Un creneau en cours, pour que l'accueil ait quelque chose a montrer.
        let slot = TimeSlot(icsUID: "demo-1", summary: "Automatique Cours magistral",
                            start: Date().addingTimeInterval(-1800),
                            end: Date().addingTimeInterval(3600))
        slot.location = "Salle 204"
        slot.course = course
        context.insert(slot)

        let later = TimeSlot(icsUID: "demo-2", summary: "Radiocommunications",
                             start: Date().addingTimeInterval(7200),
                             end: Date().addingTimeInterval(12600))
        later.location = "Amphi B"
        later.course = course
        context.insert(later)

        let activity = DailyActivity(day: Calendar.current.startOfDay(for: .now))
        activity.cardsReviewed = 3
        activity.cardsCaptured = 1
        context.insert(activity)

        let player = PlayerState()
        player.xp = 320
        player.level = 7
        player.streak = 12
        player.recordStreak = 31
        player.freezesRemaining = 2
        context.insert(player)

        try? context.save()
    }

    /// Un trace, pour que le verso d'une carte ait quelque chose a montrer.
    private static func handwriting() -> PKDrawing {
        let ink = PKInk(.pen, color: .black)
        var strokes: [PKStroke] = []
        for word in 0..<3 {
            var points: [PKStrokePoint] = []
            for step in 0..<26 {
                let t = Double(step)
                let x = Double(word) * 90 + t * 3
                let y = 40 + sin(t / 2.2) * 11
                points.append(PKStrokePoint(
                    location: CGPoint(x: x, y: y),
                    timeOffset: t / 100,
                    size: CGSize(width: 3, height: 3),
                    opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2
                ))
            }
            strokes.append(PKStroke(ink: ink, path: PKStrokePath(controlPoints: points, creationDate: Date())))
        }
        return PKDrawing(strokes: strokes)
    }
}
#endif
