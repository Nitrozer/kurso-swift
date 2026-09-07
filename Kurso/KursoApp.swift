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
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            // Placeholder de l'etape 1. Le canevas PencilKit le remplacera.
            ContentPlaceholder()
        }
        .modelContainer(container)
    }
}

private struct ContentPlaceholder: View {
    @Environment(\.modelContext) private var context
    var body: some View {
        VStack(spacing: 8) {
            Text("Kurso").font(.largeTitle.bold())
            Text("Socle en place — etape 1").foregroundStyle(.secondary)
        }
        .padding()
    }
}
