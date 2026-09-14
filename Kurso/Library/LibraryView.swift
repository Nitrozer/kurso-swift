import SwiftUI
import SwiftData
import PhotosUI
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
    /// Lance un sprint de fin de cours sur ces cartes.
    var onStartSprint: ([UUID]) -> Void = { _ in }

    @Environment(\.modelContext) private var context
    @Query(sort: \Course.name) private var courses: [Course]
    @Query private var slots: [TimeSlot]
    @Query private var assets: [PDFAsset]
    @Query(sort: \Page.createdAt, order: .reverse) private var pages: [Page]

    /// Le cahier ouvert. Nil : on regarde la planche des cahiers.
    @State private var openedCourse: Course?
    /// Les pages sans matiere, ouvertes comme un cahier a part.
    @State private var showsLoose = false
    @State private var customising: Course?
    @State private var openedPage: Page?
    @State private var query = ""
    @State private var isImporting = false
    @State private var isPickingPDF = false
    @State private var pageToDelete: Page?
    #if os(iOS)
    @State private var exported: ExportedFile?
    @State private var pendingPDF: PickedPDF?
    @State private var exportProgress: Double?
    /// La page dont la seance vient de finir, et ses cartes proposees.
    @State private var sprintFor: Page?
    /// Ou deposer les diapos qu'on est en train de choisir.
    @State private var insertionBounds: (after: Double?, before: Double?) = (nil, nil)
    @State private var pickedPhoto: PhotosPickerItem?
    @State private var photoPosition: Double?
    #endif
    @FocusState private var isSearching: Bool

    var body: some View {
        content
            .task {
                #if os(iOS)
                // Les vignettes ont besoin de retrouver le fichier d'un PDF.
                PDFAssetLookup.remember(assets)
                #endif
                #if DEBUG
                // Rejoue un import de PDF, pour voir ce qu'il cree vraiment.
                #if os(iOS)
                if ProcessInfo.processInfo.arguments.contains("-selectFirstCourse"),
                   let first = courses.first {
                    openedCourse = first
                    openFirst(of: first)
                }
                if ProcessInfo.processInfo.arguments.contains("-simulateSprint") {
                    sprintFor = pages.first { $0.sessionEnd != nil && $0.sprintProposedAt == nil }
                }
                if ProcessInfo.processInfo.arguments.contains("-simulateRemoval") {
                    isImporting = true
                }
                if ProcessInfo.processInfo.arguments.contains("-simulatePicker") {
                    pendingPDF = PickedPDF(url: URL(filePath: "/tmp/Cours de maths.pdf"))
                }
                if ProcessInfo.processInfo.arguments.contains("-simulateExport") {
                    PDFAssetLookup.remember(assets)
                    if let url = await PageExporter.write(exportablePages, fallbackName: "Essai") {
                        let size = (try? Data(contentsOf: url).count) ?? 0
                        print("[EXPORT] \(exportablePages.count) pages → \(url.path) (\(size / 1024) Ko)")
                    } else {
                        print("[EXPORT] echec")
                    }
                }
                #endif
                if ProcessInfo.processInfo.arguments.contains("-simulateImport") {
                    let source = URL(filePath: "/tmp/Cours de maths.pdf")
                    let created = try? PDFImporter.importFile(
                        at: source, course: courses.first, context: context)
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
            HStack(spacing: 0) {
                #if os(iOS)
                // Comme dans un vrai cahier : on tombe sur la feuille, et le
                // panneau sert a se deplacer dedans.
                PageNavigator(
                    pages: orderedCurrent,
                    current: page,
                    onSelect: { openedPage = $0 },
                    onAdd: { kind, position in
                        insert(kind, at: position, in: openedCourse)
                    },
                    onDuplicate: { duplicate($0) },
                    onDelete: { pageToDelete = $0 }
                )
                Rectangle().fill(K.ink.opacity(0.12)).frame(width: 1)
                #endif
                PageEditorView(page: page,
                               onClose: { closeCahier() },
                               onOpenSlide: { openedPage = $0 })
                    .id(page.id)
            }
        } else {
            library
        }
    }

    /// Entrer dans un cahier ouvre sa feuille. Vide, on lui en cree une :
    /// un cahier qu'on ouvre doit donner de quoi ecrire, pas une liste vide.
    private func openFirst(of course: Course?) {
        let existing = pages
            .filter { course == nil ? $0.course == nil : $0.course?.id == course?.id }
            .sorted { $0.position == $1.position ? $0.createdAt < $1.createdAt : $0.position < $1.position }
        if let first = existing.first { openedPage = first; return }
        #if os(iOS)
        let page = Page(createdAt: .now)
        page.course = course
        page.position = 0
        context.insert(page)
        try? context.save()
        openedPage = page
        #endif
    }

    #if os(iOS)
    /// Copier une page copie ce qu'elle porte, pas seulement son titre.
    private func duplicate(_ page: Page) {
        let copy = Page(title: page.title, createdAt: .now)
        copy.titleWasEdited = page.titleWasEdited
        copy.course = page.course
        copy.drawing = page.drawing
        copy.photo = page.photo
        copy.photoBox = page.photoBox
        copy.pdfAssetID = page.pdfAssetID
        copy.pdfPageIndex = page.pdfPageIndex
        let next = orderedCurrent.first { $0.position > page.position }?.position
        copy.position = PageOrdering.position(after: page.position, before: next)
        context.insert(copy)
        try? context.save()
        openedPage = copy
    }
    #endif

    private func closeCahier() {
        #if os(iOS)
        // Fin de seance : c'est le moment de proposer trois cartes, pas
        // pendant qu'on ecrit.
        if let page = openedPage, shouldPropose(for: page) {
            sprintFor = page
            return
        }
        #endif
        openedPage = nil
        openedCourse = nil
        showsLoose = false
    }

    #if os(iOS)
    /// Le cours vient-il de finir, avec de quoi proposer ?
    private func shouldPropose(for page: Page) -> Bool {
        guard page.sprintProposedAt == nil,
              let end = page.sessionEnd else { return false }
        let since = Date.now.timeIntervalSince(end)
        guard since >= 0, since < 45 * 60 else { return false }
        return !CardProposer.propose(from: page.recognizedText ?? "").isEmpty
    }
    #endif

    private var library: some View {
        VStack(spacing: 0) {
            header
            if !query.isEmpty {
                searchResults
            } else if isInsideCahier {
                // Etat de passage : un cahier ouvert a toujours une feuille.
                Color.clear.task { openFirst(of: openedCourse) }
            } else {
                if courses.isEmpty { importInvite }
                CahiersGrid(
                    courses: courses,
                    pageCount: { course in pages.filter { $0.course?.id == course.id }.count },
                    looseCount: pages.filter { $0.course == nil }.count,
                    onOpen: { course in
                        openedCourse = course
                        showsLoose = (course == nil)
                        openFirst(of: course)
                    },
                    onCustomise: { customising = $0 }
                )
            }
        }
        .sheet(item: $customising) { course in
            CahierSettings(course: course) { customising = nil }
        }
        #if os(iOS)
        .overlay { ExportProgress(value: exportProgress) }
        #endif
        #if os(iOS)
        .fullScreenCover(item: $sprintFor) { page in
            SprintPromptView(
                page: page,
                proposals: CardProposer.propose(from: page.recognizedText ?? ""),
                onStart: { cards in
                    page.sprintProposedAt = .now
                    try? context.save()
                    sprintFor = nil
                    openedPage = nil
                    openedCourse = nil
                    showsLoose = false
                    onStartSprint(cards.map(\.id))
                },
                onSkip: {
                    page.sprintProposedAt = .now
                    try? context.save()
                    sprintFor = nil
                    openedPage = nil
                    openedCourse = nil
                    showsLoose = false
                }
            )
        }
        #endif
        .sheet(isPresented: $isImporting) {
            TimetableOnboardingView()
        }
        #if os(iOS)
        .sheet(item: $exported) { ShareSheet(url: $0.url) }
        .photosPicker(isPresented: Binding(
            get: { photoPosition != nil },
            set: { if !$0 { photoPosition = nil } }
        ), selection: $pickedPhoto, matching: .images)
        .onChange(of: pickedPhoto) { _, item in
            guard let item, let position = photoPosition else { return }
            Task { await adoptPhoto(item, at: position) }
        }
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
            #if os(iOS)
            // On ne depose rien avant d'avoir demande quelles pages garder.
            pendingPDF = PickedPDF(url: url)
            #endif
        }
        #if os(iOS)
        .sheet(item: $pendingPDF) { picked in
            PDFPagePicker(
                url: picked.url,
                onCancel: { pendingPDF = nil },
                onConfirm: { chosen in
                    let created = try? PDFImporter.importFile(
                        at: picked.url, course: selectedCourse,
                        selected: chosen, between: insertionBounds, context: context)
                    insertionBounds = (nil, nil)
                    pendingPDF = nil
                    openedPage = created?.first
                }
            )
        }
        #endif
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
            if isInsideCahier {
                Button {
                    openedCourse = nil
                    showsLoose = false
                } label: {
                    ChevronGlyph()
                        .stroke(K.ink, style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
                        .frame(width: 13, height: 13)
                        .frame(width: 34, height: 34)
                        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .strokeBorder(K.ink, lineWidth: 2.5))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Revenir aux cahiers")
            }
            VStack(alignment: .leading, spacing: 3) {
                MetaText(headerMeta, size: 10.5)
                DisplayText(headerTitle, size: 30)
            }
            Spacer(minLength: 0)
            searchField
            if isInsideCahier { exportButton } else { importButton }
        }
        .padding(.horizontal, 28)
        .padding(.top, 22)
        .padding(.bottom, 16)
        .overlay(alignment: .bottom) {
            Rectangle().fill(K.ink.opacity(0.1)).frame(height: 1)
        }
    }

    private var headerTitle: String {
        guard isInsideCahier else { return "Mes cahiers" }
        return openedCourse?.name ?? "Sans matière"
    }

    private var headerMeta: String {
        guard isInsideCahier else {
            let n = courses.count
            return "\(n) cahier\(n > 1 ? "s" : "")".uppercased()
        }
        let count = visiblePages.count
        return "\(count) page\(count > 1 ? "s" : "")".uppercased()
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
            // A la fin de son cahier, pas au debut.
            page.position = PageOrdering.append(
                to: pages.filter { $0.course?.id == page.course?.id }.map(\.position))
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
                Task { await runExport(exportablePages, named: name) }
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

    #if os(iOS)
    /// L'export rend compte de son avancement : un cahier epais prend du temps
    /// et l'interface ne doit pas rester muette.
    private func runExport(_ list: [Page], named: String) async {
        exportProgress = 0
        let url = await PageExporter.write(list, fallbackName: named) { value in
            exportProgress = value
        }
        exportProgress = nil
        exported = url.map(ExportedFile.init)
    }

    /// Une image deposee devient une page a part entiere, a son rang.
    private func adoptPhoto(_ item: PhotosPickerItem, at position: Double) async {
        defer { pickedPhoto = nil; photoPosition = nil }
        guard let raw = try? await item.loadTransferable(type: Data.self),
              let source = UIImage(data: raw) else { return }
        let maxSide: CGFloat = 2_000
        let scale = min(1, maxSide / max(source.size.width, source.size.height))
        let size = CGSize(width: source.size.width * scale, height: source.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let reduced = UIGraphicsImageRenderer(size: size, format: format).image { context in
            context.cgContext.interpolationQuality = .high
            source.draw(in: CGRect(origin: .zero, size: size))
        }
        let page = Page(createdAt: .now)
        page.course = selectedCourse
        page.position = position
        page.photo = reduced.jpegData(compressionQuality: 0.8)
        context.insert(page)
        try? context.save()
    }
    #endif

    /// Le cahier, dans l'ordre voulu.
    private func ordered(for course: Course) -> [Page] {
        pages.filter { $0.course?.id == course.id }
            .sorted { $0.position == $1.position ? $0.createdAt < $1.createdAt : $0.position < $1.position }
    }

    #if os(iOS)
    private func move(_ page: Page, to target: Int) {
        var list = orderedCurrent
        guard let from = list.firstIndex(where: { $0.id == page.id }),
              list.indices.contains(target) else { return }
        list.remove(at: from)
        list.insert(page, at: target)
        // On renumerote la sequence entiere : plus simple a relire qu'un
        // calcul de milieu, et un cahier fait quelques dizaines de pages.
        let fresh = PageOrdering.renumbered(count: list.count)
        for (rank, item) in list.enumerated() { item.position = fresh[rank] }
        try? context.save()
    }

    private func insert(_ kind: PageNavigator.Kind, at position: Double, in course: Course?) {
        let list = orderedCurrent
        let after = list.last(where: { $0.position < position })?.position
        let before = list.first(where: { $0.position > position })?.position
        switch kind {
        case .handwritten:
            let page = Page(createdAt: .now)
            page.course = course
            page.position = position
            context.insert(page)
            try? context.save()
            openedPage = page
        case .pdf:
            insertionBounds = (after, before)
            isPickingPDF = true
        case .image:
            photoPosition = position
        }
    }
    #endif

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

    #if os(iOS)
    #endif

    private var orderedCurrent: [Page] {
        if let course = openedCourse { return ordered(for: course) }
        return pages.filter { $0.course == nil }
            .sorted { $0.position == $1.position ? $0.createdAt < $1.createdAt : $0.position < $1.position }
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

    private var selectedCourse: Course? { openedCourse }
    private var isInsideCahier: Bool { openedCourse != nil || showsLoose }

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
