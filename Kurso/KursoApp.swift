import SwiftUI
import SwiftData
import KursoModels

@main
struct KursoApp: App {
    /// Conteneur SwiftData. `cloudKitDatabase` reste desactive tant que le
    /// compte developpeur n'est pas actif : le schema est deja conforme
    /// (defauts partout, relations optionnelles avec inverse), donc le passage
    /// a `.private` se fera sans migration.
    let container: ModelContainer = {
        let schema = Schema([
            Course.self, Page.self, Card.self, Chapter.self, Season.self,
            League.self, LeagueMember.self, Assignment.self, GlossaryTerm.self,
            Abbreviation.self, AudioRecording.self, Quest.self, PlayerState.self,
            Timetable.self, TimeSlot.self, MarkerFeedback.self, PDFAsset.self, DailyActivity.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("ModelContainer: \(error)")
        }
    }()

    init() { KFont.register() }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
