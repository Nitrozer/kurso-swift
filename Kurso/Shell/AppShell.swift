import SwiftUI

/// La coquille : le rail a gauche, l'ecran actif a droite.
///
/// Remplace `NavigationSplitView`, dont les barres sont rendues par le systeme
/// et refusent d'etre stylees — elles laissaient la typographie et les pastilles
/// d'iPadOS visibles au milieu de la direction artistique.
struct AppShell: View {
    @State private var tab: RailTab = {
        #if DEBUG
        if let index = ProcessInfo.processInfo.arguments.firstIndex(of: "-startTab"),
           index + 1 < ProcessInfo.processInfo.arguments.count,
           let requested = RailTab(rawValue: ProcessInfo.processInfo.arguments[index + 1]) {
            return requested
        }
        #endif
        return .notebooks
    }()

    var body: some View {
        HStack(spacing: 0) {
            RailView(tab: $tab)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(K.paper)
        }
        // Le rail descend jusqu'en bas mais pas sous la barre d'etat : l'heure
        // du systeme est ecrite en sombre et deviendrait illisible sur le
        // graphite. Le prototype n'a pas ce probleme, c'est une maquette sans
        // barre d'etat.
        .padding(.top, 1)
        .background(K.paper)
        .ignoresSafeArea(edges: .bottom)
    }

    @ViewBuilder private var content: some View {
        switch tab {
        case .notebooks:
            LibraryView()
        case .review:
            ReviewSessionView()
        default:
            EmptyState(
                title: tab.label.capitalized,
                message: "Cet ecran arrive plus tard dans la construction."
            )
        }
    }
}
