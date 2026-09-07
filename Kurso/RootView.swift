import SwiftUI
import SwiftData
import KursoModels

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Query private var players: [PlayerState]

    /// Tant que la mise en route n'est pas faite, c'est elle qu'on voit :
    /// l'application n'a rien a montrer sans matieres.
    private var isReady: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-forceOnboarding") { return false }
        #endif
        return players.first?.hasCompletedOnboarding == true
    }

    var body: some View {
        Group {
            if isReady { AppShell() } else { OnboardingView() }
        }
            .task {
                #if DEBUG
                DebugSeed.run(context: context)
                #endif
            }
    }
}
