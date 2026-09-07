import SwiftUI
import SwiftData
import KursoModels

/// Racine de l'etape 1 : ouvre la page du jour, ou la cree si elle n'existe pas.
///
/// Provisoire — la vraie navigation (cahiers, pages datees, rail) arrive avec la
/// suite de l'etape 1. L'objectif ici est que le canevas soit atteignable et
/// que le cycle chargement / ecriture / enregistrement soit verifiable.
struct RootView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Page.createdAt, order: .reverse) private var pages: [Page]

    var body: some View {
        Group {
            if let page = todaysPage {
                PageEditorView(page: page)
            } else {
                ProgressView().task { createTodaysPage() }
            }
        }
    }

    private var todaysPage: Page? {
        pages.first { Calendar.current.isDateInToday($0.createdAt) }
    }

    private func createTodaysPage() {
        guard todaysPage == nil else { return }
        let page = Page(title: "", createdAt: .now)
        context.insert(page)
        try? context.save()
    }
}
