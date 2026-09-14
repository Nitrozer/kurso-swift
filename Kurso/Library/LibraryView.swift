import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import KursoCore
import KursoModels

enum CahierSelection: Hashable {
    case allPages
    case course(UUID)
}

/// Les cahiers : les pages d'une matiere, en ordre chronologique.
///
/// Il n'existe pas d'entite `Notebook` : les dossiers crees a la main sont
/// refuses, c'est l'emploi du temps qui range.
struct LibraryView: View {
    /// Page demandee depuis un autre ecran — l'accueil ouvre le cahier du cours.
    var pageToOpen: Binding<Page?>? = nil

    @Environment(\.modelContext) private var context
    @Query(sort: \Course.name) private var courses: [Course]
    @Query private var slots: [TimeSlot]
    @Query private var assets: [PDFAsset]
    @Query(sort: \Page.createdAt, order: .reverse) private var pages: [Page]

    @State private var selection: CahierSelection = .allPages
    @State private var openedPage: Page?
    @State private var query = ""
    @State private var isImporting = false
    @State private var isPickingPDF = false
    @State private var pageToDelete: Page?
    #if os(iOS)
    @State private var exported: ExportedFile?
    #endif
    @FocusState private var isSearching: Bool

    var body: some View {
        content
            .task {
                #if DEBUG
                // Rejoue un import de PDF, pour voir ce qu'il cree vraiment.
                #if os(iOS)
                if ProcessInfo.processInfo.arguments.contains("-simulateExport") {
                    PDFAssetLookup.remember(assets)
                    if let url = PageExporter.write(exportablePages, fallbackName: "Essai") {
                        let size = (try? Data(contentsOf: url).count) ?? 0
                        print("[EXPORT] \(exportablePages.count) pages → \(url.path) (\(size / 1024) Ko)")
                    } else {
                        print("[EXPORT] echec")
                    }
                }
                #endif
                if ProcessInfo.processInfo.arguments.contains("-simulateImport") {
                    let source = URL(filePath: "/tmp/Cours de maths.pdf")
                    let created = try? PDFImporter.importFile(at: source, course: nil, context: context)
                    print("[IMPORT] pages creees = \(created?.count ?? -1)")
                    for p in created ?? [] {
                        print("[IMPORT]   titre=\(p.title.isEmpty ? "(VIDE)" : p.title) diapo=\(p.pdfPageIndex.map(String.init) ?? "-")")
                    }
                    print("[IMPORT] total pages en base = \(pages.count)")
                }
                // Sert a photographier le canevas sans passer par le doigt.
                if ProcessInfo.processInfo.arguments.contains("-openFirstPage") {
                    openedPage = pages.first
                }
                #endif
            }
            .task(id: pageToOpen?.wrappedValue?.id) {
                if let requested = pageToOpen?.wrappedValue {
                    openedPage = requested
                    pageToOpen?.wrappedValue = nil
                }
            }
    }

    @ViewBuilder private var content: some View {
        if let page = openedPage {
            PageEditorView(page: page,
                           onClose: { openedPage = nil },
                           onOpenSlide: { openedPage = $0 })
                .id(page.id)
        } else {
            library
        }
    }

    private var library: some View {
        VStack(spacing: 0) {
            header
            toolbar
            if courses.isEmpty { importInvite }
            grid
        }
        .sheet(isPresented: $isImporting) {
            TimetableOnboardingView()
        }
        #if os(iOS)
        .sheet(item: $exported) { ShareSheet(url: $0.url) }
        #endif
        .confirmationDialog(
            "Supprimer cette page ?",
            isPresented: Binding(get: { pageToDelete != nil }, set: { if !$0 { pageToDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Supprimer", role: .destructive) { deletePage() }
            Button("Annuler", role: .cancel) { pageToDelete = nil }
        } message: {
            // Une page emporte ses cartes : il faut le dire avant, pas apres.
            Text(deletionWarning)
        }
        .fileImporter(isPresented: $isPickingPDF, allowedContentTypes: [.pdf]) { result in
            guard case .success(let url) = result else { return }
            let pages = try? PDFImporter.importFile(at: url, course: selectedCourse, context: context)
            openedPage = pages?.first
        }
    }

    /// Tant qu'aucun emploi du temps n'est importe, les pages ne peuvent pas se
    /// ranger seules — c'est l'emploi du temps qui range (§12).
    private var importInvite: some View {
        Button { isImporting = true } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Importe ton emploi du temps")
                        .font(KFont.body(13.5, weight: .extraBold))
                        .foregroundStyle(K.ink)
                    Text("Tes pages se rangeront seules dans la bonne matière.")
                        .font(KFont.body(12, weight: .bold))
                        .foregroundStyle(K.inkBody)
                }
                Spacer(minLength: 0)
                ChevronGlyph(pointsRight: true)
                    .stroke(K.ink, style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
                    .frame(width: 12, height: 12)
            }
            .padding(16)
            .sticker(fill: K.reward, radius: 16)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 28)
        .padding(.top, 16)
    }

    // MARK: En-tete

    private var header: some View {
        HStack(alignment: .bottom, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                MetaText(headerMeta, size: 10.5)
                DisplayText("Mes pages", size: 30)
            }
            Spacer(minLength: 0)
            searchField
            newPageButton
        }
        .padding(.horizontal, 28)
        .padding(.top, 22)
        .padding(.bottom, 16)
        .overlay(alignment: .bottom) {
            Rectangle().fill(K.ink.opacity(0.1)).frame(height: 1)
        }
    }

    private var headerMeta: String {
        let name = selectedCourse?.name ?? "Toutes les matières"
        let count = visiblePages.count
        return "\(name) · \(count) page\(count > 1 ? "s" : "")"
    }

    /// « Chercher dans l'ecriture » : la requete porte sur le texte reconnu,
    /// jamais sur une reecriture des notes.
    private var searchField: some View {
        HStack(spacing: 8) {
            Glyph(kind: .search, size: 14, color: K.inkSoft)
            TextField("Chercher dans l'écriture", text: $query)
                .textFieldStyle(.plain)
                .font(KFont.body(12, weight: .bold))
                .foregroundStyle(K.ink)
                .focused($isSearching)
                .frame(width: 190)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Glyph(kind: .plus, size: 11, color: K.inkSoft)
                        .rotationEffect(.degrees(45))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Effacer la recherche")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .overlay(Capsule().strokeBorder(K.ink, lineWidth: 2.5))
    }

    private var newPageButton: some View {
        Button {
            let page = Page(createdAt: .now)
            context.insert(page)
            // Le creneau en cours prime sur le filtre affiche : c'est l'emploi
            // du temps qui range, pas la colonne qu'on regardait (§12).
            if PageAttachment.attach(page, context: context) == nil {
                page.course = selectedCourse
            }
            try? context.save()
            openedPage = page
        } label: {
            HStack(spacing: 8) {
                Glyph(kind: .plus, size: 14, color: K.paperAlt)
                Text("Nouvelle page")
                    .font(KFont.body(12.5, weight: .extraBold))
                    .foregroundStyle(K.paperAlt)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 8)
            .background(K.brand, in: Capsule())
            .overlay(Capsule().strokeBorder(K.ink, lineWidth: 3))
            .background(alignment: .top) { Capsule().fill(K.ink).offset(y: 3) }
        }
        .buttonStyle(.plain)
    }

    // MARK: Filtre par matiere

    /// Filtres a gauche, actions de rangement a droite : la ligne du haut
    /// garde la seule action qu'on vient chercher, ecrire.
    private var toolbar: some View {
        HStack(spacing: 12) {
            if courses.isEmpty {
                Spacer(minLength: 0)
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 9) {
                        chip("Toutes", isActive: selection == .allPages) { selection = .allPages }
                        ForEach(courses) { course in
                            chip(course.name, isActive: selection == .course(course.id)) {
                                selection = .course(course.id)
                            }
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
            }
            HStack(spacing: 9) {
                exportButton
                importButton
                pdfButton
            }
            .padding(.trailing, 28)
            .padding(.leading, courses.isEmpty ? 28 : 0)
        }
        .padding(.vertical, 12)
    }

    private func chip(_ label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(KFont.body(12, weight: .extraBold))
                .foregroundStyle(isActive ? K.paperAlt : K.ink)
                .padding(.horizontal, 13)
                .padding(.vertical, 7)
                .background(isActive ? K.ink : .clear, in: Capsule())
                .overlay(Capsule().strokeBorder(K.ink, lineWidth: 2.5))
        }
        .buttonStyle(.plain)
    }

    /// Depot d'un polycopie : une page Kurso par diapo.
    /// Exporte tout ce que la colonne affiche, diapos comprises.
    @ViewBuilder private var exportButton: some View {
        #if os(iOS)
        if !pages.isEmpty {
            Button {
                PDFAssetLookup.remember(assets)
                let name = selectedCourse?.name ?? "Mes pages"
                exported = PageExporter.write(exportablePages, fallbackName: name)
                    .map(ExportedFile.init)
            } label: {
                Text("Exporter")
                    .font(KFont.body(12, weight: .extraBold))
                    .foregroundStyle(K.ink)
                    .padding(.horizontal, 13).padding(.vertical, 7)
                    .overlay(Capsule().strokeBorder(K.ink, lineWidth: 2.5))
            }
            .buttonStyle(.plain)
        }
        #endif
    }

    /// Toutes les pages du cahier affiche : ici on ne regroupe PAS les diapos,
    /// on veut le document entier.
    private var exportablePages: [Page] {
        let ofCourse = selectedCourse.map { course in
            pages.filter { $0.course?.id == course.id }
        } ?? pages
        return ofCourse.sorted {
            if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
            return ($0.pdfPageIndex ?? 0) < ($1.pdfPageIndex ?? 0)
        }
    }

    private var pdfButton: some View {
        Button { isPickingPDF = true } label: {
            HStack(spacing: 7) {
                Glyph(kind: .plus, size: 12)
                Text("Déposer un PDF")
                    .font(KFont.body(12, weight: .extraBold))
                    .foregroundStyle(K.ink)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .overlay(Capsule().strokeBorder(K.ink, lineWidth: 2.5))
        }
        .buttonStyle(.plain)
    }

    /// Ouvre l'emploi du temps : import la premiere fois, consultation ensuite.
    private var importButton: some View {
        Button { isImporting = true } label: {
            HStack(spacing: 7) {
                if slots.isEmpty { Glyph(kind: .plus, size: 12) }
                Text(slots.isEmpty ? "Importer l'emploi du temps" : "Emploi du temps")
                    .font(KFont.body(12, weight: .extraBold))
                    .foregroundStyle(K.ink)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .overlay(Capsule().strokeBorder(K.ink, lineWidth: 2.5))
        }
        .buttonStyle(.plain)
    }

    // MARK: Grille de pages

    @ViewBuilder private var grid: some View {
        if !query.isEmpty {
            searchResults
        } else if visiblePages.isEmpty {
            EmptyState(title: "Aucune page", message: "Créez la première page de ce cahier.")
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    ForEach(days, id: \.start) { day in
                        VStack(alignment: .leading, spacing: 11) {
                            MetaText(day.start.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                                .padding(.horizontal, 28)
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(day.items) { page in
                                    PageCard(page: page,
                                             slideCount: slideCount(of: page),
                                             action: { openedPage = page },
                                             onDelete: { pageToDelete = page })
                                }
                            }
                            .padding(.horizontal, 28)
                        }
                    }
                }
                .padding(.vertical, 20)
            }
            .scrollIndicators(.hidden)
        }
    }

    @ViewBuilder private var searchResults: some View {
        let hits = TextSearch.rank(visiblePages, query: query) { $0.recognizedText }
        if hits.isEmpty {
            EmptyState(
                title: "Rien trouvé",
                message: "Aucune page ne contient « \(query) ». La recherche porte sur l'écriture reconnue."
            )
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 11) {
                    MetaText("\(hits.count) resultats")
                        .padding(.horizontal, 28)
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(hits, id: \.item.id) { hit in
                            PageCard(page: hit.item,
                                     action: { openedPage = hit.item },
                                     onDelete: { pageToDelete = hit.item })
                        }
                    }
                    .padding(.horizontal, 28)
                }
                .padding(.vertical, 20)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.adaptive(minimum: 168, maximum: 260), spacing: 16), count: 1)
    }

    // MARK: Donnees derivees

    private var deletionWarning: String {
        let cards = (pageToDelete?.cards ?? []).count
        let title = pageToDelete?.title.isEmpty == false ? "« \(pageToDelete!.title) »" : "Cette page"
        guard cards > 0 else { return "\(title) sera supprimée. C'est définitif." }
        return "\(title) sera supprimée, avec \(cards) carte(s) de révision. C'est définitif."
    }

    private func deletePage() {
        guard let page = pageToDelete else { return }
        if openedPage?.id == page.id { openedPage = nil }
        context.delete(page)
        try? context.save()
        pageToDelete = nil
    }

    private var selectedCourse: Course? {
        guard case .course(let id) = selection else { return nil }
        return courses.first { $0.id == id }
    }

    private var visiblePages: [Page] {
        let byCourse = selectedCourse.map { course in
            pages.filter { $0.course?.id == course.id }
        } ?? pages
        return Page.collapsingSlides(byCourse)
    }

    /// Nombre de diapos d'un PDF, pour l'afficher sur sa vignette.
    private func slideCount(of page: Page) -> Int? {
        guard let asset = page.pdfAssetID else { return nil }
        let count = pages.filter { $0.pdfAssetID == asset }.count
        return count > 1 ? count : nil
    }

    private var days: [DayGrouping.Day<Page>] {
        DayGrouping.byDay(visiblePages) { $0.createdAt }
    }
}
