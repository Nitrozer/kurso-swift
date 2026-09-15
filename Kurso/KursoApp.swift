import SwiftUI
import SwiftData
import KursoModels

@main
struct KursoApp: App {
    /// Conteneur SwiftData, partage avec les intents Siri (voir KursoStore).
    let container: ModelContainer = KursoStore.container

    init() { KFont.register() }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
