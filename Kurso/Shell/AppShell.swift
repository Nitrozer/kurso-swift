import SwiftUI
import SwiftData
import KursoCore
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
    /// Ce qu'un intent Siri a demande avant que l'interface existe.
    @State private var router = IntentRouter.shared
    @State private var showsAccount = false

    var body: some View {
        // On mesure la marge haute pour poser le rail SOUS la barre d'etat.
        // En paysage il la touchait, et iOS, voyant du graphite dessous,
        // basculait l'heure et la date en blanc — illisibles sur le papier
        // du reste de l'ecran.
        GeometryReader { geo in
            shell(topInset: geo.safeAreaInsets.top)
        }
        .ignoresSafeArea()
    }

    private func shell(topInset: CGFloat) -> some View {
        VStack(spacing: 0) {
            // Une bande de papier sous la barre d'etat, sur toute la largeur.
            // Le rail est en graphite : quelle que soit la couleur choisie par
            // iOS pour l'heure, elle etait illisible sur l'un ou sur l'autre.
            // Lui donner un fond clair unique regle les deux cas.
            // En paysage, iPadOS n'annonce aucune marge haute : sans
            // plancher, la bande disparaissait et le contenu remontait sous
            // l'heure.
            K.paper.frame(height: max(topInset, 22))
            body(topInset: topInset)
        }
    }

    private func body(topInset: CGFloat) -> some View {
        HStack(spacing: 0) {
            if railShown {
                RailView(tab: $tab, onAvatar: { showsAccount = true })
                    .transition(.move(edge: .leading))
            }
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(K.paper)
                .overlay(alignment: .bottomLeading) { railToggle }
        }
        .animation(.snappy(duration: 0.28), value: railShown)
        #if os(iOS)
        .fullScreenCover(isPresented: $showsAccount) {
            AccountView(onClose: { showsAccount = false }, onOpenLeague: {
                showsAccount = false
                tab = .day
            })
        }
        #else
        .sheet(isPresented: $showsAccount) {
            AccountView(onClose: { showsAccount = false }, onOpenLeague: {
                showsAccount = false
                tab = .day
            })
        }
        #endif
        // Siri a pu demander un onglet avant que la fenetre soit la : on
        // consomme la demande a l'affichage, puis on l'efface.
        .onAppear { consumeIntent() }
        .onChange(of: router.pendingTab) { _, _ in consumeIntent() }
        #if DEBUG
        .task {
            // Rejoue le geste : on ecrit, puis on part ailleurs. La palette
            // ne doit pas suivre.
            guard ProcessInfo.processInfo.arguments.contains("-simulateLeavePage") else { return }
            try? await Task.sleep(for: .seconds(6))
            tab = .day
        }
        #endif
        #if DEBUG
        .task {
            guard ProcessInfo.processInfo.arguments.contains("-openAccount") else { return }
            try? await Task.sleep(for: .seconds(2))
            showsAccount = true
        }
        // Rejoue un intent Siri : rien d'autre ne peut le declencher ici.
        .task {
            let args = ProcessInfo.processInfo.arguments
            guard let index = args.firstIndex(of: "-simulateIntent"),
                  index + 1 < args.count else { return }
            try? await Task.sleep(for: .seconds(3))
            switch args[index + 1] {
            case "review":
                _ = try? await StartReviewIntent().perform()
                print("[INTENT] revision demandee")
            case "count":
                let due = KursoIntentSupport.dueCount()
                print("[INTENT] dues=\(due) — « \(ReviewAnnouncement.sentence(due: due)) »")
            case "cahier":
                let context = ModelContext(KursoStore.container)
                let courses = (try? context.fetch(FetchDescriptor<Course>())) ?? []
                guard let first = courses.first else { print("[INTENT] aucun cahier"); return }
                let intent = OpenCahierIntent()
                intent.cahier = CahierEntity(id: first.id, name: first.name)
                _ = try? await intent.perform()
                print("[INTENT] cahier=\(first.name)")
            default:
                print("[INTENT] inconnu")
            }
        }
        #endif
        // Le rail descend jusqu'en bas mais pas sous la barre d'etat : l'heure
        // du systeme est ecrite en sombre et deviendrait illisible sur le
        // graphite. Le prototype n'a pas ce probleme, c'est une maquette sans
        // barre d'etat.
        .padding(.top, 1)
        .background(K.paper)
    }

    private func consumeIntent() {
        guard let wanted = router.pendingTab else { return }
        tab = wanted
        router.pendingTab = nil
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
            MemoryMapView { ids in
                sprintCards = ids
                tab = .review
            }
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
