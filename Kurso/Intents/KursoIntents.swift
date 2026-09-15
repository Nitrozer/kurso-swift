import AppIntents
import SwiftData
import KursoCore
import KursoModels

/// Les actions que Siri peut declencher (§12).
///
/// Trois verbes, et aucun qui redige : ouvrir la revision, ouvrir un cahier,
/// compter les cartes dues. Rien ici ne resume un cours, ne reecrit une note
/// ni ne fabrique une carte — c'est la ligne du §12, et elle vaut aussi pour
/// l'assistant. Aucun intent ne rend le contenu d'une page ou d'une carte.
enum KursoIntentSupport {

    /// Les cartes dues maintenant. Un nombre, jamais leur texte.
    @MainActor
    static func dueCount(now: Date = .now) -> Int {
        let context = ModelContext(KursoStore.container)
        let cards = (try? context.fetch(FetchDescriptor<Card>())) ?? []
        return cards.filter { $0.dueAt <= now }.count
    }
}

/// « Lance ma session de révision »
struct StartReviewIntent: AppIntent {
    static let title: LocalizedStringResource = "Lancer la révision"
    static let description = IntentDescription(
        "Ouvre Kurso sur les cartes à réviser aujourd'hui."
    )
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        IntentRouter.shared.pendingTab = .review
        let due = KursoIntentSupport.dueCount()
        return .result(dialog: IntentDialog(stringLiteral: ReviewAnnouncement.sentence(due: due)))
    }
}

/// « Combien de cartes à réviser ? » — sans ouvrir l'application.
struct DueCardsIntent: AppIntent {
    static let title: LocalizedStringResource = "Cartes à réviser"
    static let description = IntentDescription(
        "Dit combien de cartes attendent, sans ouvrir Kurso."
    )
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<Int> {
        let due = KursoIntentSupport.dueCount()
        return .result(value: due,
                       dialog: IntentDialog(stringLiteral: ReviewAnnouncement.sentence(due: due)))
    }
}

/// « Ouvre mon cahier d'automatique »
struct OpenCahierIntent: AppIntent {
    static let title: LocalizedStringResource = "Ouvrir un cahier"
    static let description = IntentDescription("Ouvre un cahier par sa matière.")
    static let openAppWhenRun = true

    @Parameter(title: "Cahier")
    var cahier: CahierEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Ouvrir \(\.$cahier)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        IntentRouter.shared.pendingCourseID = cahier.id
        IntentRouter.shared.pendingTab = .notebooks
        return .result(dialog: IntentDialog(stringLiteral: ReviewAnnouncement.opening(cahier.name)))
    }
}

/// Les phrases que Siri reconnait sans que l'utilisateur configure quoi que ce soit.
struct KursoShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartReviewIntent(),
            phrases: [
                "Lance ma session de révision dans \(.applicationName)",
                "Révise avec \(.applicationName)",
                "Start my review in \(.applicationName)",
            ],
            shortTitle: "Réviser",
            systemImageName: "rectangle.stack"
        )
        AppShortcut(
            intent: DueCardsIntent(),
            phrases: [
                "Combien de cartes dans \(.applicationName)",
                "Mes cartes à réviser dans \(.applicationName)",
            ],
            shortTitle: "Cartes dues",
            systemImageName: "number"
        )
        AppShortcut(
            intent: OpenCahierIntent(),
            phrases: [
                "Ouvre un cahier dans \(.applicationName)",
                "Open a notebook in \(.applicationName)",
            ],
            shortTitle: "Ouvrir un cahier",
            systemImageName: "book.closed"
        )
    }
}
