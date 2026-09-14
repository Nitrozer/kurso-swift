import SwiftUI
import KursoModels

/// La coquille : le rail a gauche, l'ecran actif a droite.
///
/// Remplace `NavigationSplitView`, dont les barres sont rendues par le systeme
/// et refusent d'etre stylees — elles laissaient la typographie et les pastilles
/// d'iPadOS visibles au milieu de la direction artistique.
struct AppShell: View {
    @State private var pageToOpen: Page?
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

    /// Le rail se replie : sur un iPad en portrait, cent points de moins
    /// changent tout pour ecrire.
    @State private var railShown = true
    /// Les cartes d'un sprint de fin de cours, en attente d'etre affrontees.
    @State private var sprintCards: [UUID]?

    var body: some View {
        HStack(spacing: 0) {
            if railShown {
                RailView(tab: $tab)
                    .transition(.move(edge: .leading))
            }
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(K.paper)
                .overlay(alignment: .bottomLeading) { railToggle }
        }
        .animation(.snappy(duration: 0.28), value: railShown)
        #if DEBUG
        .task {
            // Rejoue le geste : on ecrit, puis on part ailleurs. La palette
            // ne doit pas suivre.
            guard ProcessInfo.processInfo.arguments.contains("-simulateLeavePage") else { return }
            try? await Task.sleep(for: .seconds(6))
            tab = .day
        }
        #endif
        // Le rail descend jusqu'en bas mais pas sous la barre d'etat : l'heure
        // du systeme est ecrite en sombre et deviendrait illisible sur le
        // graphite. Le prototype n'a pas ce probleme, c'est une maquette sans
        // barre d'etat.
        .padding(.top, 1)
        .background(K.paper)
        .ignoresSafeArea(edges: .bottom)
    }

    /// Le bouton qui replie et deplie le rail.
    private var railToggle: some View {
        Button { railShown.toggle() } label: {
            ChevronGlyph()
                .stroke(K.ink, style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                .frame(width: 10, height: 10)
                .rotationEffect(.degrees(railShown ? 0 : 180))
                .frame(width: 26, height: 26)
                .background(K.paperAlt, in: Circle())
                .overlay(Circle().strokeBorder(K.ink, lineWidth: 2))
        }
        .buttonStyle(.plain)
        // En bas : en haut il chevauchait l'en-tete du panneau des pages.
        .padding(.leading, 8)
        .padding(.bottom, 14)
        .accessibilityLabel(railShown ? "Replier le menu" : "Déplier le menu")
    }

    @ViewBuilder private var content: some View {
        switch tab {
        case .day:
            DayView(tab: $tab) { page in
                pageToOpen = page
                tab = .notebooks
            }
        case .notebooks:
            LibraryView(pageToOpen: $pageToOpen) { ids in
                sprintCards = ids
                tab = .review
            }
        case .review:
            ReviewSessionView(sprintCardIDs: sprintCards)
                .id(sprintCards?.first)
                .onDisappear { sprintCards = nil }
        case .memory:
            MemoryMapView()
        case .cards:
            FichesView()
        default:
            EmptyState(
                title: tab.label.capitalized,
                message: "Cet écran arrive plus tard dans la construction."
            )
        }
    }
}
