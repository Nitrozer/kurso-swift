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

        #if os(iOS)
        // Une carte tiree d'une diapo, pour verifier son rendu en revision.
        let masked = Card(question: "Que cache cette zone ?", kind: .imageOcclusion, dueAt: .now)
        masked.occlusionRect = CGRect(x: 0.12, y: 0.18, width: 0.55, height: 0.14)
        masked.imageData = demoSlide()
        masked.page = page
        context.insert(masked)
        #endif

        // Quelques pages aux etats varies, pour voir les trois raretes de fiche.
        for (title, cards, acquired, lapses) in [
            ("Tri par tas", 4, 4, 0),
            ("Diviser pour régner", 5, 4, 0),
            ("Files de priorité", 6, 1, 3),
            ("Graphes pondérés", 0, 0, 0),
        ] {
            let extra = Page(title: title, createdAt: .now)
            extra.titleWasEdited = true
            extra.course = course
            context.insert(extra)
            for index in 0..<cards {
                let card = Card(question: "\(title) — \(index + 1)", kind: .frontBack, dueAt: .now)
                // Une carte acquise a un long intervalle et n'est pas en retard.
                card.interval = index < acquired ? 21 : 1
                card.dueAt = index < acquired ? Date().addingTimeInterval(86_400 * 10) : Date()
                card.lapses = index < lapses ? 1 : 0
                card.page = extra
                context.insert(card)
            }
        }

        // Une page dont la seance vient de finir, avec de quoi proposer.
        let justFinished = Page(title: "Tas binaires", createdAt: .now)
        justFinished.titleWasEdited = true
        justFinished.course = course
        justFinished.sessionEnd = Date().addingTimeInterval(-300)
        justFinished.recognizedText = """
        Tas binaires
        Tas binaire : arbre presque complet ou chaque parent domine ses enfants
        Hauteur = ⌊log₂ n⌋
        Insertion → O(log n) par remontee
        on remonte l'element tant que le parent est plus grand, ce qui donne la borne
        """
        context.insert(justFinished)

        #if DEBUG
        // Verifie que SwiftData accepte un tableau d'horodatages : c'est la
        // meme famille de type que le CGRect qui plantait.
        if ProcessInfo.processInfo.arguments.contains("-checkAudioModel") {
            let rec = AudioRecording(fileName: "essai.m4a", startedAt: .now)
            rec.durationSeconds = 42
            rec.strokeTimestamps = [
                StrokeTimestamp(strokeID: UUID(), offsetSeconds: 1.5),
                StrokeTimestamp(strokeID: UUID(), offsetSeconds: 9.25),
            ]
            rec.page = page
            context.insert(rec)
            do {
                try context.save()
                let back = (try? context.fetch(FetchDescriptor<AudioRecording>()))?.first
                print("[AUDIO] enregistre · horodatages relus = \(back?.strokeTimestamps.count ?? -1)")
            } catch {
                print("[AUDIO] ECHEC: \(error)")
            }
        }
        #endif

        let player = PlayerState()
        player.xp = 320
        player.level = 7
        player.streak = 12
        player.recordStreak = 31
        player.freezesRemaining = 2
        player.displayName = "Thomas"
        // Les donnees de demo sautent la mise en route : on veut voir l'app.
        player.hasCompletedOnboarding = true
        context.insert(player)

        try? context.save()
    }

    /// Un trace, pour que le verso d'une carte ait quelque chose a montrer.
    #if os(iOS)
    /// Une fausse diapo : bandeau de titre, deux paragraphes.
    private static func demoSlide() -> Data? {
        let size = CGSize(width: 1_200, height: 850)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            UIColor(red: 0.23, green: 0.36, blue: 1, alpha: 1).setFill()
            ctx.fill(CGRect(x: 70, y: 90, width: 900, height: 110))
            UIColor(white: 0.85, alpha: 1).setFill()
            for row in 0..<5 {
                ctx.fill(CGRect(x: 70, y: 300 + row * 70, width: 1_000 - row * 90, height: 26))
            }
        }.jpegData(compressionQuality: 0.8)
    }
    #endif

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
