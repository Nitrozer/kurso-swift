import SwiftUI
import SwiftData
import PhotosUI
#if os(iOS)
import UIKit
#endif
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
    /// Le panneau des pages se replie, comme celui des cartes.
    @State private var navigatorShown = true
    /// Change pour demander a la feuille d'ouvrir le selecteur d'image.
    @State private var addImageRequest: UUID?
    @State private var openedCourse: Course?
    /// Les pages sans matiere, ouvertes comme un cahier a part.
    @State private var showsLoose = false
    @State private var customising: Course?
    @State private var openedPage: Page?
    @State private var query = ""
    @State private var searchFilter: SearchKind = .all
    @State private var isImporting = false
    @State private var isPickingPDF = false
    @State private var pageToDelete: Page?
    /// Le cahier qu'un intent Siri a demande, par identifiant.
    @State private var router = IntentRouter.shared
    /// La derniere page ouverte, pour y revenir au lancement suivant.
    ///
    /// Dans les reglages de l'appareil et non dans `PlayerState` : c'est une
    /// commodite locale, pas une donnee a synchroniser. Reprendre sur l'iPad
    /// la page qu'on lisait sur le Mac n'aurait aucun sens.
    @AppStorage("kurso.lastOpenedPage") private var lastOpenedPage: String = ""
    @State private var hasResumed = false
    #if os(iOS)
    @State private var backupFile: ExportedFile?
    @State private var isPickingBackup = false
    @State private var pendingRestore: PendingRestore?
    @State private var backupError: String?
    #endif
    #if os(iOS)
    @State private var exported: ExportedFile?
    @State private var pendingPDF: PickedPDF?
    @State private var exportProgress: Double?
    /// La page dont la seance vient de finir, et ses cartes proposees.
    @State private var sprintFor: Page?
    /// Demande depuis le menu de la page plutot qu'a la fin d'un cours.
    @State private var sprintWasManual = false
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
                if ProcessInfo.processInfo.arguments.contains("-openSettings"),
                   let first = courses.first {
                    customising = first
                }
                if ProcessInfo.processInfo.arguments.contains("-checkPageActions") {
                    let before = pages.count
                    if let first = orderedCurrent.first ?? pages.first {
                        duplicate(first)
                        let afterCopy = (try? context.fetch(FetchDescriptor<Page>()))?.count ?? -1
                        pageToDelete = openedPage
                        deletePage()
                        let afterDelete = (try? context.fetch(FetchDescriptor<Page>()))?.count ?? -1
                        print("[PAGES] avant=\(before) apres duplication=\(afterCopy) apres suppression=\(afterDelete)")
                    } else {
                        print("[PAGES] aucune page")
                    }
                }
                if ProcessInfo.processInfo.arguments.contains("-openLoose") {
                    showsLoose = true
                    openFirst(of: nil)
                }
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
                // Aller-retour complet : sauvegarder, tout effacer, restaurer.
                // Une sauvegarde qu'on ne relit pas ne prouve rien.
                if ProcessInfo.processInfo.arguments.contains("-simulateBackup") {
                    let made = BackupStore.archive(context)
                    let data = (try? Backup.encode(made)) ?? Data()
                    let octets = data.count
                    let before = "\(made.courses.count)c \(made.pages.count)p \(made.cards.count)k "
                        + "\(made.images.count)i \(made.assets.count)pdf \(made.slots.count)s"
                    let drawings = made.pages.filter { ($0.drawing?.count ?? 0) > 0 }.count
                    do {
                        let reread = try Backup.decode(data)
                        try BackupStore.restore(reread, context: context)
                        let after = BackupStore.archive(context)
                        let afterLine = "\(after.courses.count)c \(after.pages.count)p \(after.cards.count)k "
                            + "\(after.images.count)i \(after.assets.count)pdf \(after.slots.count)s"
                        let keptDrawings = after.pages.filter { ($0.drawing?.count ?? 0) > 0 }.count
                        print("[BACKUP] \(octets) octets · avant \(before) traits=\(drawings)")
                        print("[BACKUP] apres  \(afterLine) traits=\(keptDrawings)")
                        print("[BACKUP] identique=\(before == afterLine && drawings == keptDrawings)")
                    } catch {
                        print("[BACKUP] ECHEC \(error)")
                    }
                }
                if let index = ProcessInfo.processInfo.arguments.firstIndex(of: "-simulateSearch"),
                   index + 1 < ProcessInfo.processInfo.arguments.count {
                    query = ProcessInfo.processInfo.arguments[index + 1]
                    print("[RECHERCHE] « \(query) » → \(searchRows.count) rangee(s)")
                }
                if ProcessInfo.processInfo.arguments.contains("-openFirstPage") {
                    openedPage = pages.first
                }
                // La page rattachee a un cours termine, celle qui a de quoi
                // proposer des cartes.
                if ProcessInfo.processInfo.arguments.contains("-openFinishedPage"),
                   let finished = pages.first(where: { $0.sessionEnd != nil }) {
                    openedCourse = finished.course
                    showsLoose = finished.course == nil
                    openedPage = finished
                }
                #endif
            }
            .onChange(of: openedPage?.id) { _, id in
                lastOpenedPage = id?.uuidString ?? ""
            }
            .task { resumeIfPossible() }
            .task(id: pageToOpen?.wrappedValue?.id) {
                if let requested = pageToOpen?.wrappedValue {
                    // Le cahier suit la page : sans lui, le panneau listait
                    // les pages sans matiere — donc aucune — et annoncait
                    // « 0 page » sur un cahier qui en a six.
                    openedCourse = requested.course
                    showsLoose = requested.course == nil
                    openedPage = requested
                    pageToOpen?.wrappedValue = nil
                }
            }
            // Siri ne designe qu'un identifiant : c'est ici qu'on retrouve le
            // cahier, et jamais l'intent qui lit son contenu.
            .task(id: router.pendingCourseID) { openRequestedCahier() }
    }

    @ViewBuilder private var content: some View {
        // La confirmation vit ICI, pas sur `library` : quand une page est
        // ouverte, `library` n'est pas affichee, et la boite n'existait donc
        // pas au moment ou le panneau la demandait.
        Group {
        if let page = openedPage {
            HStack(spacing: 0) {
                #if os(iOS)
                if !navigatorShown {
                    // Une poignee sur toute la hauteur, comme le bord d'un
                    // tiroir : un carre de 26 sur 44 colle en haut de l'ecran
                    // se rate une fois sur deux.
                    Button { navigatorShown = true } label: {
                        ZStack {
                            K.paperAlt
                            ChevronGlyph()
                                .stroke(K.ink, style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                                .frame(width: 10, height: 10)
                                .rotationEffect(.degrees(180))
                        }
                        .frame(width: 30)
                        .frame(maxHeight: .infinity)
                        .overlay(alignment: .trailing) {
                            Rectangle().fill(K.ink.opacity(0.12)).frame(width: 1)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Déplier les pages")
                }
                if navigatorShown {
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
                    onDelete: { pageToDelete = $0 },
                    onCollapse: { navigatorShown = false }
                )
                .transition(.move(edge: .leading))
                Rectangle().fill(K.ink.opacity(0.12)).frame(width: 1)
                }
                #endif
                PageEditorView(page: page,
                               onClose: { closeCahier() },
                               onOpenSlide: { openedPage = $0 },
                               addImageRequest: addImageRequest,
                               isCoveredBySheet: sheetIsUp,
                               onProposeCards: { asked in
                                   #if os(iOS)
                                   sprintWasManual = true
                                   sprintFor = asked
                                   #endif
                               })
                    .id(page.id)
            }
            .animation(.snappy(duration: 0.28), value: navigatorShown)
        } else {
            library
        }
        }
        #if os(iOS)
        .sheet(item: $backupFile) { ShareSheet(url: $0.url) }
        .fileImporter(isPresented: $isPickingBackup, allowedContentTypes: [.json, .data]) { result in
            readBackup(result)
        }
        .alert("Restaurer cette sauvegarde ?", isPresented: Binding(
            get: { pendingRestore != nil },
            set: { if !$0 { pendingRestore = nil } })) {
            Button("Remplacer tout", role: .destructive) {
                if let pending = pendingRestore { applyRestore(pending.archive) }
            }
            Button("Annuler", role: .cancel) { pendingRestore = nil }
        } message: {
            Text("Elle contient \(pendingRestore?.archive.summary ?? ""). Tout ce qui est actuellement dans Kurso sera remplacé.")
        }
        .alert("Sauvegarde", isPresented: Binding(
            get: { backupError != nil },
            set: { if !$0 { backupError = nil } })) {
            Button("OK", role: .cancel) { backupError = nil }
        } message: {
            Text(backupError ?? "")
        }
        .fullScreenCover(item: $sprintFor) { page in
            SprintPromptView(
                page: page,
                proposals: CardProposer.propose(from: page.recognizedText ?? ""),
                isManual: sprintWasManual,
                onStart: { cards in
                    page.sprintProposedAt = .now
                    try? context.save()
                    closeAfterSprint()
                    onStartSprint(cards.map(\.id))
                },
                onSkip: {
                    // Demande a la main : on refuse juste cette fois, et la
                    // proposition de fin de cours reste due.
                    if !sprintWasManual {
                        page.sprintProposedAt = .now
                        try? context.save()
                        closeAfterSprint()
                    } else {
                        sprintFor = nil
                    }
                }
            )
        }
        #endif
        .confirmationDialog(
            "Supprimer cette page ?",
            isPresented: Binding(get: { pageToDelete != nil },
                                 set: { if !$0 { pageToDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Supprimer", role: .destructive) { deletePage() }
            Button("Annuler", role: .cancel) { pageToDelete = nil }
        } message: {
            // Une page emporte ses cartes : il faut le dire avant, pas apres.
            Text(deletionWarning)
        }
        #if DEBUG
        // Rejoue le geste signale : une page est ouverte, on demande un PDF
        // depuis le « + » du panneau. La feuille doit s'ouvrir PAR-DESSUS
        // l'editeur, sans qu'on ait a revenir aux cahiers.
        .task {
            #if os(iOS)
            guard ProcessInfo.processInfo.arguments.contains("-simulatePDFOverPage") else { return }
            try? await Task.sleep(for: .seconds(5))
            print("[PDF] page ouverte=\(openedPage != nil) — on demande le selecteur")
            pendingPDF = PickedPDF(url: URL(filePath: "/tmp/Cours de maths.pdf"))
            #endif
        }
        #endif
        // TOUTES les presentations vivent ici, sur le Group, et jamais sur
        // `library` : le « + » du panneau des pages s'utilise alors qu'une
        // page est ouverte, moment ou `library` n'est pas dans la
        // hierarchie. Une feuille qu'on lui accroche ne s'ouvre donc
        // jamais — il fallait revenir a la planche des cahiers pour la voir
        // apparaitre. Troisieme fois que ce piege se referme ici.
        .sheet(item: $customising) { course in
            CahierSettings(course: course) { customising = nil }.macSheet(560, 560)
        }
        #if os(iOS)
        .overlay { ExportProgress(value: exportProgress) }
        #endif
        .sheet(isPresented: $isImporting) {
            TimetableOnboardingView().macSheet(760, 640)
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

    #if os(iOS)
    /// Apres un sprint : on sort du cahier, la revision prend la main.
    private func closeAfterSprint() {
        sprintFor = nil
        openedPage = nil
        openedCourse = nil
        showsLoose = false
    }
    #endif

    /// Rouvre la derniere page ecrite, une seule fois par lancement.
    ///
    /// On ne s'impose pas : si quelque chose a deja demande une page — un
    /// intent Siri, l'ecran Jour, un drapeau de debug — on lui laisse la main.
    private func resumeIfPossible() {
        guard !hasResumed else { return }
        hasResumed = true
        guard openedPage == nil, pageToOpen?.wrappedValue == nil,
              router.pendingCourseID == nil,
              let id = UUID(uuidString: lastOpenedPage),
              let page = pages.first(where: { $0.id == id }),
              page.course?.archivedAt == nil
        else { return }
        openedCourse = page.course
        showsLoose = page.course == nil
        openedPage = page
        #if DEBUG
        print("[REPRISE] \(page.title.isEmpty ? "sans titre" : page.title)")
        #endif
    }

    /// Une feuille est-elle ouverte par-dessus la page ?
    private var sheetIsUp: Bool {
        #if os(iOS)
        pendingPDF != nil || photoPosition != nil || isPickingPDF
            || sprintFor != nil || exported != nil || customising != nil
        #else
        customising != nil
        #endif
    }

    private func openRequestedCahier() {
        guard let wanted = router.pendingCourseID else { return }
        router.pendingCourseID = nil
        guard let course = courses.first(where: { $0.id == wanted }) else { return }
        openedCourse = course
        showsLoose = false
        openFirst(of: course)
    }

    private func closeCahier() {
        #if os(iOS)
        // Fin de seance : c'est le moment de proposer trois cartes, pas
        // pendant qu'on ecrit.
        if let page = openedPage, shouldPropose(for: page) {
            sprintWasManual = false
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
                GribouBubble(tips: cahierTips, mood: .idle)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 14)
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
            #if os(iOS)
            if !isInsideCahier { backupMenu }
            #endif
        }
        .padding(.horizontal, 28)
        .padding(.top, 22)
        .padding(.bottom, 16)
        .overlay(alignment: .bottom) {
            Rectangle().fill(K.ink.opacity(0.1)).frame(height: 1)
        }
    }

    #if os(iOS)
    /// Sauvegarder et restaurer. Tant que CloudKit dort, les cahiers n'existent
    /// qu'ici : c'est la seule copie possible.
    private var backupMenu: some View {
        Menu {
            Button("Sauvegarder mes cahiers") { makeBackup() }
            Button("Restaurer une sauvegarde…") { isPickingBackup = true }
        } label: {
            Text("···")
                .font(KFont.body(15, weight: .extraBold))
                .foregroundStyle(K.ink)
                .frame(width: 36, height: 34)
                .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(K.ink, lineWidth: 2.5))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .accessibilityLabel("Sauvegarde")
    }

    struct PendingRestore: Identifiable {
        let id = UUID()
        let archive: Backup.Archive
    }

    private func makeBackup() {
        do { backupFile = ExportedFile(url: try BackupStore.write(context)) }
        catch { backupError = "La sauvegarde n'a pas pu être écrite." }
    }

    /// On annonce ce que contient le fichier AVANT de remplacer quoi que ce
    /// soit : une restauration efface tout, ca ne se decide pas a l'aveugle.
    private func readBackup(_ result: Result<URL, Error>) {
        isPickingBackup = false
        guard case .success(let url) = result else { return }
        let opened = url.startAccessingSecurityScopedResource()
        defer { if opened { url.stopAccessingSecurityScopedResource() } }
        do {
            pendingRestore = PendingRestore(archive: try Backup.decode(try Data(contentsOf: url)))
        } catch Backup.Failure.tooRecent(let version) {
            backupError = "Cette sauvegarde vient d'une version plus récente de Kurso (format \(version))."
        } catch {
            backupError = "Ce fichier n'est pas une sauvegarde Kurso lisible."
        }
    }

    private func applyRestore(_ archive: Backup.Archive) {
        pendingRestore = nil
        openedPage = nil
        openedCourse = nil
        showsLoose = false
        do { try BackupStore.restore(archive, context: context) }
        catch { backupError = "La restauration a échoué. Rien n'a été remplacé." }
    }
    #endif

    /// Ce que Gribou POURRAIT dire sur la planche des cahiers. Il n'en dira
    /// qu'un, et seulement s'il reste du budget (§12).
    private var cahierTips: [GribouAdvice.Tip] {
        var tips: [GribouAdvice.Tip] = []

        let fading = pages.filter { page in
            let cards = page.cards ?? []
            guard !cards.isEmpty, page.course?.archivedAt == nil else { return false }
            let state = Freshness.state(cards: cards.map {
                Freshness.CardState(dueAt: $0.dueAt, interval: $0.interval)
            })
            return state == .endangered || state == .toReview
        }
        if fading.count >= 2 {
            tips.append(.init(
                id: "cahiers.palissent",
                kind: .action,
                text: "\(fading.count) pages pâlissent. Une session les remonte — le plus urgent est en tête de pile."))
        }

        let drafts = pages.filter { ($0.cards ?? []).isEmpty && $0.course?.archivedAt == nil }
        if drafts.count >= 3 {
            tips.append(.init(
                id: "cahiers.brouillons",
                kind: .debrief,
                text: "\(drafts.count) pages n'ont encore aucune carte. Masque une zone pour en tirer une."))
        }

        tips.append(.init(
            id: "cahiers.rangement",
            kind: .mechanic,
            text: "Tu n'as aucun dossier à créer : l'emploi du temps range chaque page dans le bon cahier, datée et située."))

        if !courses.isEmpty, fading.isEmpty {
            tips.append(.init(
                id: "cahiers.ajour",
                kind: .cheer,
                text: "Tout est à jour. C'est rare — profites-en pour prendre de l'avance."))
        }
        return tips
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

    /// D'ou vient le texte trouve. La maquette le dit sur chaque rangee :
    /// chercher dans son ecriture n'a d'interet que si l'on voit OU ca a ete
    /// trouve, et sous quelle forme.
    enum SearchKind: String, CaseIterable, Identifiable {
        case all, handwritten, typed, photo, cards
        var id: String { rawValue }

        var chip: String {
            switch self {
            case .all:         "Tout"
            case .handwritten: "Manuscrit"
            case .typed:       "Tapé"
            case .photo:       "Photos du tableau"
            case .cards:       "Cartes"
            }
        }
        var badge: String {
            switch self {
            case .typed: "TAPÉ"
            case .photo: "PHOTO"
            case .cards: "CARTE"
            default:     "MANUSCRIT"
            }
        }
        var tint: Color {
            switch self {
            case .typed: K.brand
            case .photo: K.eraser
            case .cards: K.success
            default:     K.reward
            }
        }
    }

    struct SearchRow: Identifiable {
        let id: UUID
        let page: Page
        let kind: SearchKind
        let excerpt: TextSearch.Excerpt
    }

    /// Toutes les correspondances, quelle que soit leur forme.
    private var searchRows: [SearchRow] {
        var rows: [SearchRow] = []
        for page in visiblePages {
            // Le texte augmente des abreviations sert a TROUVER la page (§4) ;
            // l'extrait montre, lui, ce que la page dit vraiment.
            let searchable = Abbreviations.searchableText(page.recognizedText)
            let matchesPage = !TextSearch.rank([page], query: query) { _ in searchable }.isEmpty

            if !page.markdown.isEmpty,
               let excerpt = TextSearch.excerpt(from: page.markdown, query: query) {
                rows.append(SearchRow(id: page.id, page: page, kind: .typed, excerpt: excerpt))
            } else if matchesPage,
                      let excerpt = TextSearch.excerpt(from: page.recognizedText, query: query) {
                let kind: SearchKind = (page.photo != nil || page.pdfAssetID != nil) ? .photo : .handwritten
                rows.append(SearchRow(id: page.id, page: page, kind: kind, excerpt: excerpt))
            }

            for card in page.cards ?? [] {
                let text = card.question + "\n" + (card.answerText ?? "")
                if let excerpt = TextSearch.excerpt(from: text, query: query) {
                    rows.append(SearchRow(id: card.id, page: page, kind: .cards, excerpt: excerpt))
                }
            }
        }
        return rows
    }

    private var filteredRows: [SearchRow] {
        searchFilter == .all ? searchRows : searchRows.filter { $0.kind == searchFilter }
    }

    @ViewBuilder private var searchResults: some View {
        let rows = filteredRows
        VStack(alignment: .leading, spacing: 0) {
            searchChips
            if rows.isEmpty {
                EmptyState(
                    title: "Rien trouvé",
                    message: "Aucune page ne contient « \(query) ». La recherche porte sur l'écriture reconnue."
                )
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(rows) { searchRow($0) }
                        searchNote
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 18)
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private var searchChips: some View {
        HStack(spacing: 8) {
            ForEach(SearchKind.allCases) { kind in
                let count = kind == .all ? searchRows.count : searchRows.filter { $0.kind == kind }.count
                let active = searchFilter == kind
                Button { searchFilter = kind } label: {
                    Text(kind.chip)
                        .font(KFont.body(12, weight: .extraBold))
                        .foregroundStyle(active ? K.paperAlt : K.ink)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(active ? K.brand : K.paperAlt, in: Capsule())
                        .overlay(Capsule().strokeBorder(K.ink, lineWidth: 2.5))
                }
                .buttonStyle(.plain)
                .opacity(count == 0 && kind != .all ? 0.4 : 1)
                .disabled(count == 0 && kind != .all)
            }
            Spacer(minLength: 0)
            Text(searchCount)
                .font(KFont.mono(10))
                .tracking(1)
                .foregroundStyle(K.inkSoft)
        }
        .padding(.horizontal, 28)
        .padding(.top, 14)
    }

    private var searchCount: String {
        let total = searchRows.count
        let written = searchRows.filter { $0.kind == .handwritten }.count
        var text = "\(total) RÉSULTAT\(total > 1 ? "S" : "")"
        if written > 0 { text += " · \(written) MANUSCRIT\(written > 1 ? "S" : "")" }
        return text
    }

    private func searchRow(_ row: SearchRow) -> some View {
        Button { openedCourse = row.page.course; showsLoose = row.page.course == nil; openedPage = row.page } label: {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 9) {
                    Circle()
                        .fill(K.cahier(CourseColor.named(row.page.course?.colorToken ?? "grey")))
                        .frame(width: 13, height: 13)
                        .overlay(Circle().strokeBorder(K.ink, lineWidth: 2))
                    Text(row.page.course?.name ?? "Sans matière")
                        .font(KFont.body(13, weight: .extraBold))
                        .foregroundStyle(K.ink)
                    Text(rowMeta(row))
                        .font(KFont.mono(10))
                        .foregroundStyle(K.inkSoft)
                    Spacer(minLength: 8)
                    Text(row.kind.badge)
                        .font(KFont.body(9.5, weight: .extraBold))
                        .tracking(0.8)
                        .foregroundStyle(K.ink)
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background(row.kind.tint.opacity(0.35), in: Capsule())
                }
                highlighted(row.excerpt)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(K.paperAlt, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(K.ink.opacity(0.12), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    private func rowMeta(_ row: SearchRow) -> String {
        let day = row.page.createdAt.formatted(.dateTime.day().month(.twoDigits))
        return "\(row.page.title.isEmpty ? "sans titre" : row.page.title) · \(day)"
    }

    /// Le terme surligne, comme sur la maquette : c'est lui qu'on cherchait.
    ///
    /// `AttributedString` et non une concatenation de `Text` : seule la
    /// premiere sait poser un fond sur une partie de la phrase.
    private func highlighted(_ excerpt: TextSearch.Excerpt) -> Text {
        let characters = Array(excerpt.line)
        var result = AttributedString("")
        var index = 0

        for range in excerpt.highlights where range.lowerBound >= index {
            if range.lowerBound > index {
                result += AttributedString(String(characters[index..<range.lowerBound]))
            }
            var marked = AttributedString(String(characters[range.lowerBound..<range.upperBound]))
            marked.backgroundColor = K.reward
            marked.foregroundColor = K.ink
            result += marked
            index = range.upperBound
        }
        if index < characters.count {
            result += AttributedString(String(characters[index...]))
        }
        return Text(result)
            .font(KFont.body(14, weight: .bold))
            .foregroundColor(K.inkBody)
    }

    private var searchNote: some View {
        HStack(spacing: 13) {
            GribouView(mood: .concentre, size: 64)
            Text("Ton écriture est indexée sur l'appareil, au fil de la frappe du Pencil. Chercher un mot écrit à la main marche aussi bien que du texte tapé — et sans connexion.")
                .font(KFont.body(12.5, weight: .bold))
                .foregroundStyle(K.inkBody)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(K.ink.opacity(0.15), lineWidth: 1.5))
        .padding(.top, 8)
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
