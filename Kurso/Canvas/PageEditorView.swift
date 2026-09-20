import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers
import PencilKit
import KursoCore
import KursoModels

/// Editeur d'une page. Sur iPad, le canevas PencilKit ; sur Mac, un ecran
/// Mac : l.ecriture se relit a cote du volet markdown (§11, etape 1).
struct PageEditorView: View {
    @Bindable var page: Page
    var onClose: () -> Void = {}
    /// Ouvre une autre diapo du meme PDF.
    var onOpenSlide: (Page) -> Void = { _ in }
    /// Demande venue du panneau : ouvrir le selecteur d'image.
    var addImageRequest: UUID?
    /// Demander des cartes a la main, sans attendre la fin d'un cours.
    var onProposeCards: (Page) -> Void = { _ in }
    /// Une feuille s'ouvre par-dessus : le canevas doit rendre le premier
    /// repondant, sans quoi la palette PencilKit flotte au-dessus d'elle.
    /// Seul l'editeur connait son canevas, d'ou ce signal venu du parent.
    var isCoveredBySheet: Bool = false
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    @State private var drawing: PKDrawing
    @State private var clock = WritingClock()
    /// Affiche le temps d'ecriture reel, pas le temps d'ecran.
    @State private var displayedSeconds = 0
    @State private var loadFailed = false
    @State private var recognitionTask: Task<Void, Never>?
    @State private var isMasking = false
    /// Le volet des cartes capturees. On l'enleve pour ecrire large.
    @State private var marginShown = true
    @State private var isCapturing = false
    /// Une image survole la page, prete a etre lachee.
    @State private var isDropTargeted = false
    @State private var pendingCapture: PKDrawing?
    /// La diapo rasterisee, passee au fond du canevas pour qu'elle defile et
    /// zoome avec l'ecriture — la poser derriere le canevas la laissait
    /// immobile, et le papier la recouvrait.
    @State private var backdropImage: CGImage?
    /// Zoom et defilement du canevas, dont le fond se sert pour se caler.
    @State private var viewport = PaperBackdrop.Viewport()
    /// La zone visible de la diapo, rendue plus finement en zoomant.
    @State private var backdropTile: PaperBackdrop.Tile?
    @State private var tileTask: Task<Void, Never>?
    @Environment(\.displayScale) private var displayScale
    @FocusState private var titleFocused: Bool
    #if os(iOS)
    @State private var isCapturingRegion = false
    @State private var pendingImage: CGImage?
    @State private var pickedPhoto: PhotosPickerItem?
    @State private var isPickingPDF = false
    @State private var pendingPDF: PickedPDF?
    @State private var isAdjustingPhoto = false
    /// Pourquoi on ouvre le selecteur de photos.
    ///
    /// Un seul `.photosPicker` par vue : en poser deux les fait se neutraliser,
    /// et aucun ne s'ouvrait.
    private enum PhotoPurpose { case background, placed }
    /// L'intention SURVIT a la fermeture du selecteur.
    ///
    /// Elle etait portee par le binding de presentation : se fermer la remettait
    /// a nil, et la photo choisie arrivait apres — donc toujours ignoree.
    @State private var photoPurpose: PhotoPurpose = .placed
    @State private var isPickingPhoto = false
    /// L'appareil photo est ouvert.
    @State private var isTakingPhoto = false
    @State private var recorder = LectureRecorder()
    /// Les traits horodates de l'enregistrement en cours.
    @State private var marks: [StrokeTimestamp] = []
    /// Mode ecoute : toucher un mot rejoue ce que le prof disait.
    @State private var isListening = false
    @State private var audioNotice: String?
    /// Les images posees, decodees une fois.
    @State private var placed: [PaperBackdrop.Placed] = []
    /// L'image touchee, s'il y en a une.
    @State private var selectedImage: UUID?
    /// Une image ajoutee depuis le panneau, pas en fond de page.
    /// Le volet des cartes capturees. On l'enleve pour ecrire large.
    @State private var exportProgress: Double?
    @State private var exported: ExportedFile?
    #endif
    #if os(iOS)
    @State private var canvasHandle = CanvasHandle()
    #endif
    @Query private var assets: [PDFAsset]
    @Query private var allPages: [Page]
    @Query(sort: \Course.name) private var courses: [Course]

    /// Le trace est lu ICI, avant que la vue existe.
    ///
    /// Le charger plus tard laissait une fenetre ou le canevas etait construit
    /// vide : PencilKit signalait ce vide comme un changement, on l'enregistrait
    /// par-dessus la page, et le travail etait perdu a la simple ouverture.
    init(page: Page,
         onClose: @escaping () -> Void = {},
         onOpenSlide: @escaping (Page) -> Void = { _ in },
         addImageRequest: UUID? = nil,
         isCoveredBySheet: Bool = false,
         onProposeCards: @escaping (Page) -> Void = { _ in }) {
        _page = Bindable(page)
        self.onClose = onClose
        self.onOpenSlide = onOpenSlide
        self.addImageRequest = addImageRequest
        self.isCoveredBySheet = isCoveredBySheet
        self.onProposeCards = onProposeCards
        let stored = page.drawing
        let hasStored = !(stored ?? Data()).isEmpty
        let loaded = hasStored ? try? PKDrawing(data: stored!) : PKDrawing()
        _drawing = State(initialValue: loaded ?? PKDrawing())
        // On n'ecrase pas ce qu'on n'a pas su relire.
        _loadFailed = State(initialValue: hasStored && loaded == nil)
        #if DEBUG
        print("[KURSO] ouverture traits=\(loaded?.strokes.count ?? -1) octets=\(stored?.count ?? 0)")
        #endif
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            #if os(iOS)
            HStack(spacing: 0) {
            ZStack {
                PaperBackdrop(
                    viewport: viewport,
                    template: PaperKind.named(page.templateRaw),
                    pageSize: CGSize(width: DrawingCanvas.pageWidth,
                                     height: DrawingCanvas.pageHeight),
                    backdrop: backdropImage,
                    backdropTile: backdropTile,
                    backdropBox: page.photoRect,
                    placed: placed
                )
                DrawingCanvas(
                drawing: $drawing,
                handle: canvasHandle,
                onViewportChange: { viewport = $0 },
                onBeginWriting: { clock.begin(at: .now) },
                onEndWriting: { latest in
                    clock.end(at: .now)
                    drawing = latest
                    noteStroke(latest)
                    persist(latest)
                }
            )
                if isMasking, let index = page.pdfPageIndex {
                    OcclusionLayer(
                        page: page,
                        pageIndex: index,
                        viewport: viewport,
                        slideImage: backdropImage,
                        slideBox: page.photoRect
                    ) { isMasking = false }
                }
                if isAdjustingPhoto, let source = backdropImage {
                    PhotoAdjustLayer(
                        current: photoFrameOnScreen(source),
                        onChange: { rect in savePhotoFrame(rect) },
                        onReset: { page.photoRect = nil; try? context.save() },
                        onDone: { isAdjustingPhoto = false }
                    )
                }
                imagesLayer
                if isListening {
                    ListeningLayer(
                        marks: listeningMarks,
                        viewport: viewport,
                        onPick: { play($0) },
                        onClose: { isListening = false; recorder.stopPlaying() }
                    )
                }
                if isCapturingRegion {
                    RegionCaptureLayer(
                        onCapture: { rect in
                            pendingImage = regionImage(rect)
                            isCapturingRegion = false
                        },
                        onCancel: { isCapturingRegion = false }
                    )
                }
                if isCapturing {
                    CaptureLayer(
                        drawing: drawing,
                        handle: canvasHandle,
                        onCapture: { captured in
                            pendingCapture = captured
                            isCapturing = false
                        },
                        onCancel: { isCapturing = false }
                    )
                }
            }
            // On depose une image n'importe ou sur la page : une capture
            // d'ecran glissee depuis le Mac, une photo venue de Fichiers.
            // Elle se pose la ou on la lache, pas en haut de page.
            .onDrop(of: [.image], isTargeted: $isDropTargeted) { providers, location in
                receiveDrop(providers, at: location)
            }
            .overlay {
                if isDropTargeted {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(K.brand, style: StrokeStyle(lineWidth: 4, dash: [10, 7]))
                        .overlay(alignment: .top) {
                            Text("DÉPOSER ICI")
                                .font(KFont.body(11, weight: .extraBold))
                                .tracking(1)
                                .foregroundStyle(K.paperAlt)
                                .padding(.horizontal, 14).padding(.vertical, 7)
                                .background(K.brand, in: Capsule())
                                .padding(.top, 16)
                        }
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
            .animation(.snappy(duration: 0.18), value: isDropTargeted)
            // Le bouton vit AU BORD du volet, pas dans l'en-tete : on y va
            // avec le pouce, sans traverser l'ecran.
            Button { marginShown.toggle() } label: {
                ChevronGlyph()
                    .stroke(K.ink, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                    .frame(width: 9, height: 9)
                    .rotationEffect(.degrees(marginShown ? 180 : 0))
                    .frame(width: 26, height: 44)
                    .background(K.paperAlt)
                    .overlay(alignment: .leading) {
                        Rectangle().fill(K.ink.opacity(0.12)).frame(width: 1)
                    }
            }
            .buttonStyle(.plain)
            .frame(maxHeight: .infinity, alignment: .top)
            .accessibilityLabel(marginShown ? "Cacher les cartes" : "Montrer les cartes")

            if marginShown {
                TaskMargin(page: page)
                    .transition(.move(edge: .trailing))
            }
            }
            #else
            // Sur Mac : le manuscrit se relit, le markdown s'ecrit. PKCanvasView
            // n'existe pas sur macOS, mais PKDrawing sait se rendre en image.
            HSplitView {
                DrawingPreview(drawing: drawing)
                    .frame(minWidth: 260, idealWidth: 420)
                MarkdownPane(page: page)
                    .frame(minWidth: 320)
            }
            #endif
        }
        .background(K.paper)
        .sheet(item: Binding(
            get: { pendingCapture.map { CaptureDraft(drawing: $0) } },
            set: { if $0 == nil { pendingCapture = nil } }
        )) { draft in
            CapturePrompt(page: page, answer: draft.drawing) { pendingCapture = nil }
        }
        #if os(iOS)
        .sheet(item: Binding(
            get: { pendingImage.map { ImageDraft(image: $0) } },
            set: { if $0 == nil { pendingImage = nil } }
        )) { draft in
            CapturePrompt(page: page, image: draft.image) { pendingImage = nil }
        }
        #endif
        #if os(iOS)
        .task { await loadPDF() }
        .onChange(of: viewport) { scheduleTile() }
        .task {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-simulateRegion") {
                try? await Task.sleep(for: .seconds(4))
                // Une region qui couvre la bande rouge du PDF d'essai.
                if let image = regionImage(CGRect(x: 40, y: 60, width: 520, height: 260)) {
                    let url = FileManager.default.temporaryDirectory.appending(path: "region.png")
                    try? UIImage(cgImage: image).pngData()?.write(to: url)
                    print("[REGION] \(image.width)x\(image.height) → \(url.path)")
                } else {
                    print("[REGION] echec")
                }
            }
            if ProcessInfo.processInfo.arguments.contains("-simulateOcclusion") {
                try? await Task.sleep(for: .seconds(1))
                isMasking = true
            }
            #endif
        }
        #endif
        .task {
            load()
            #if DEBUG
            #if os(iOS)
            // Rejoue l'entree de menu, qu'aucun tap ne peut atteindre ici.
            // Rejoue un depot d'image a un point donne de l'ecran, pour
            // verifier que l'image tombe bien la ou on la lache.
            if let i = ProcessInfo.processInfo.arguments.firstIndex(of: "-simulateDrop"),
               i + 1 < ProcessInfo.processInfo.arguments.count {
                let parts = ProcessInfo.processInfo.arguments[i + 1].split(separator: ",").compactMap { Double($0) }
                if parts.count == 2 {
                    try? await Task.sleep(for: .seconds(3))
                    let point = CGPoint(x: parts[0], y: parts[1])
                    let swatch = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 260)).image { ctx in
                        UIColor.systemTeal.setFill()
                        ctx.fill(CGRect(x: 0, y: 0, width: 400, height: 260))
                    }
                    insert(swatch, droppedAt: point)
                    print("[KURSO] depot a \(point) → fraction \(String(describing: pageFraction(of: point)))")
                }
            }
            if ProcessInfo.processInfo.arguments.contains("-simulateProposeCards") {
                try? await Task.sleep(for: .seconds(4))
                print("[KURSO] propositions=\(cardProposals.count)")
                proposeCards()
            }
            #endif
            // Rejoue le geste complet : on ecrit, puis on appuie sur retour.
            if ProcessInfo.processInfo.arguments.contains("-simulateBack") {
                try? await Task.sleep(for: .seconds(6))
                print("[KURSO] --- appui sur retour ---")
                closePage()
            }
            #endif
        }
        #if os(iOS)
        .onChange(of: isCoveredBySheet) { _, covered in
            if covered { canvasHandle.pauseWriting() } else { resumeWriting() }
        }
        // Le champ du titre prend le premier repondant, et la palette
        // PencilKit disparait avec. On la rend des qu'on quitte le champ.
        .onChange(of: titleFocused) { _, focused in
            if !focused { resumeWriting() }
        }
        .onChange(of: isMasking) { _, masking in
            if !masking { resumeWriting() }
        }
        // Revenir de l'arriere-plan laissait la palette rangee.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { resumeWriting() }
        }
        #endif
        #if os(iOS)
        .sheet(item: $exported) { ShareSheet(url: $0.url) }
        #if os(iOS)
        .photosPicker(isPresented: $isPickingPhoto,
                      selection: $pickedPhoto, matching: .images)
        // Plein ecran : un appareil photo dans une petite feuille ne sert a
        // rien, on ne voit pas ce qu'on cadre.
        .fullScreenCover(isPresented: $isTakingPhoto) {
            CameraPicker(
                onCapture: { image in
                    isTakingPhoto = false
                    insert(image)
                },
                onCancel: { isTakingPhoto = false }
            )
            .ignoresSafeArea()
        }
        #endif
        .alert("Enregistrement",
               isPresented: Binding(get: { audioNotice != nil },
                                    set: { if !$0 { audioNotice = nil } })) {
            Button("D'accord", role: .cancel) { audioNotice = nil }
        } message: {
            Text(audioNotice ?? "")
        }
        .fileImporter(isPresented: $isPickingPDF, allowedContentTypes: [.pdf]) { result in
            guard case .success(let url) = result else { return }
            pendingPDF = PickedPDF(url: url)
        }
        .sheet(item: $pendingPDF) { picked in
            PDFPagePicker(
                url: picked.url,
                onCancel: { pendingPDF = nil },
                onConfirm: { chosen in
                    // Les diapos rejoignent la matiere de la note ouverte.
                    let created = try? PDFImporter.importFile(
                        at: picked.url, course: page.course,
                        selected: chosen, context: context)
                    pendingPDF = nil
                    if let first = created?.first { onOpenSlide(first) }
                }
            )
        }
        #endif
        .animation(.snappy(duration: 0.28), value: marginShown)
        #if os(iOS)
        .onChange(of: pickedPhoto) { _, item in
            guard let item else { return }
            let purpose = photoPurpose
            Task {
                switch purpose {
                case .background: await adopt(item)
                case .placed:     await adoptPlaced(item)
                }
            }
        }
        .task { reloadPlaced() }
        #if os(iOS)
        .onChange(of: addImageRequest) { _, value in
            if value != nil { photoPurpose = .placed; isPickingPhoto = true }
        }
        #endif
        #endif
        #if os(iOS)
        .overlay { ExportProgress(value: exportProgress) }
        #endif
        .onDisappear {
            // Un enregistrement en cours se termine et se garde : partir
            // ailleurs ne doit pas effacer une heure de cours.
            #if os(iOS)
            if recorder.isRecording { finishRecording() }
            recorder.stopPlaying()
            #endif
            persist()
            #if os(iOS)
            // Filet : quitter l'onglet ne demonte pas toujours le canevas.
            canvasHandle.canvas?.resignFirstResponder()
            #endif
        }
    }

    /// Quitter la page. Le retour peut ouvrir les propositions de cartes sans
    /// demonter l'editeur : la palette resterait alors au-dessus d'elles.
    private func closePage() {
        persist()
        #if os(iOS)
        canvasHandle.canvas?.resignFirstResponder()
        #endif
        onClose()
    }

    /// L'en-tete : le titre, UNE action, et tout le reste range.
    ///
    /// Elle portait sept boutons cote a cote — audio, volet, papier, image,
    /// matiere, export, mode — et devenait illisible des qu'on ouvrait le
    /// panneau des pages. On ne garde a l'air libre que ce qui se decide sans
    /// reflechir.
    private var header: some View {
        HStack(spacing: 12) {
            Button {
                closePage()
            } label: {
                ChevronGlyph()
                    .stroke(K.ink, style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
                    .frame(width: 13, height: 13)
                    .frame(width: 34, height: 34)
                    .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(K.ink, lineWidth: 2.5))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Retour aux pages")

            VStack(alignment: .leading, spacing: 2) {
                TextField("Page sans titre", text: Binding(
                    get: { page.title },
                    set: { newValue in
                        page.title = newValue
                        page.titleWasEdited = !newValue.trimmingCharacters(in: .whitespaces).isEmpty
                        try? context.save()
                    }
                ))
                .textFieldStyle(.plain)
                .focused($titleFocused)
                .submitLabel(.done)
                .onSubmit { titleFocused = false }
                .font(KFont.display(19))
                .foregroundStyle(K.ink)
                .frame(minWidth: 90, idealWidth: 200, maxWidth: 260, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

                MetaText(subtitleLine, size: 9.5)
            }

            slideNav

            Spacer(minLength: 8)

            if loadFailed { unreadableBadge }
            #if os(iOS)
            if recorder.isRecording { recordingChip }
            primaryAction
            pageMenu
            #endif
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle().fill(K.ink.opacity(0.1)).frame(height: 1)
        }
    }

    /// La ligne sous le titre : la date, et la matiere quand il y en a une.
    private var subtitleLine: String {
        let day = page.createdAt.formatted(.dateTime.weekday(.wide).day().month(.wide))
        guard let course = page.course else { return day.uppercased() }
        return "\(day) · \(course.name)".uppercased()
    }

    private var unreadableBadge: some View {
        // Un dessin illisible ne doit jamais etre ecrase en silence (§8).
        Text("DESSIN ILLISIBLE")
            .font(KFont.mono(10))
            .tracking(1.2)
            .foregroundStyle(K.paperAlt)
            .padding(.horizontal, 11).padding(.vertical, 5)
            .background(K.alertBg, in: Capsule())
            .overlay(Capsule().strokeBorder(K.ink, lineWidth: 2.5))
    }

    private var pdfAsset: PDFAsset? {
        guard let id = page.pdfAssetID else { return nil }
        return assets.first { $0.id == id }
    }

    /// Le rattachement automatique ne joue que pendant un creneau. Hors cours,
    /// il faut pouvoir ranger sa page soi-meme — sinon une note ecrite le
    /// dimanche reste orpheline pour toujours.
    /// Passer d'une diapo a l'autre sans repasser par les cahiers : les diapos
    /// d'un meme PDF n'y forment plus qu'une seule entree.
    @ViewBuilder private var slideNav: some View {
        let siblings = slideSiblings
        if siblings.count > 1, let position = siblings.firstIndex(where: { $0.id == page.id }) {
            HStack(spacing: 8) {
                Button { jump(to: siblings, position - 1) } label: { navChevron(flipped: false) }
                    .buttonStyle(.plain)
                    .disabled(position == 0)
                    .opacity(position == 0 ? 0.35 : 1)
                Text("\(position + 1) / \(siblings.count)")
                    .font(KFont.mono(11))
                    .foregroundStyle(K.inkSoft)
                Button { jump(to: siblings, position + 1) } label: { navChevron(flipped: true) }
                    .buttonStyle(.plain)
                    .disabled(position == siblings.count - 1)
                    .opacity(position == siblings.count - 1 ? 0.35 : 1)
            }
        }
    }

    private func navChevron(flipped: Bool) -> some View {
        ChevronGlyph()
            .stroke(K.ink, style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
            .frame(width: 11, height: 11)
            .rotationEffect(.degrees(flipped ? 180 : 0))
            .frame(width: 30, height: 30)
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(K.ink, lineWidth: 2))
    }

    /// Le cadre de l'image, tel qu'il tombe a l'ecran.
    private func photoFrameOnScreen(_ source: CGImage) -> CGRect {
        PaperBackdrop.placement(
            image: CGSize(width: source.width, height: source.height),
            box: page.photoRect, in: pageRectOnScreen)
    }

    private var pageRectOnScreen: CGRect {
        CGRect(x: -viewport.offset.x, y: -viewport.offset.y,
               width: PaperBackdrop.pageWidth * viewport.zoom,
               height: PaperBackdrop.pageHeight * viewport.zoom)
    }

    /// Repasse du repere ecran aux fractions de page, seules stables au zoom.
    private func savePhotoFrame(_ rect: CGRect) {
        let pageRect = pageRectOnScreen
        guard pageRect.width > 0, pageRect.height > 0 else { return }
        page.photoRect = CGRect(x: (rect.minX - pageRect.minX) / pageRect.width,
                                y: (rect.minY - pageRect.minY) / pageRect.height,
                                width: rect.width / pageRect.width,
                                height: rect.height / pageRect.height)
        try? context.save()
    }

    #if os(iOS)
    private var hasRecording: Bool { !(page.recordings ?? []).isEmpty }

    /// Les traits horodates de la page, prets pour l'ecoute.
    private var listeningMarks: [AudioSync.Mark] {
        (page.recordings ?? []).flatMap { recording in
            recording.strokeTimestamps.map {
                AudioSync.Mark(strokeID: $0.strokeID,
                               offsetSeconds: $0.offsetSeconds,
                               anchor: CGPoint(x: $0.anchorX, y: $0.anchorY))
            }
        }
    }

    private func beginRecording() async {
        marks = []
        if await recorder.start() == false {
            audioNotice = "Kurso n'a pas pu enregistrer. Vérifie l'accès au micro dans Réglages."
        }
    }

    /// Un trait termine retient l'instant ou il a ete trace (§7).
    private func noteStroke(_ latest: PKDrawing) {
        guard recorder.isRecording, let stroke = latest.strokes.last else { return }
        let centre = stroke.renderBounds
        marks.append(StrokeTimestamp(
            strokeID: UUID(),
            offsetSeconds: recorder.currentTime,
            anchorX: centre.midX,
            anchorY: centre.midY
        ))
    }

    private func finishRecording() {
        guard let done = recorder.stop() else {
            audioNotice = "Rien n'a été enregistré."
            return
        }
        let recording = AudioRecording(fileName: done.fileName, startedAt: .now)
        recording.durationSeconds = done.duration
        recording.strokeTimestamps = marks
        recording.page = page
        context.insert(recording)
        try? context.save()
        audioNotice = "Enregistrement gardé : \(AudioSync.clock(done.duration)), \(marks.count) repère\(marks.count > 1 ? "s" : "") d'écriture."
        marks = []
    }

    /// Lire tout, sans viser un mot : c'est ce qui permet de verifier qu'un
    /// enregistrement existe vraiment.
    private func playFromStart() {
        guard let recording = (page.recordings ?? []).last else {
            audioNotice = "Aucun enregistrement sur cette page."
            return
        }
        recorder.play(recording.fileName, from: 0)
        audioNotice = "Lecture de \(AudioSync.clock(recording.durationSeconds))."
    }

    /// Les images posees : zones sensibles seulement, le dessin vient du fond.
    @ViewBuilder private var imagesLayer: some View {
        if !(page.images ?? []).isEmpty {
            PlacedImagesLayer(
                items: (page.images ?? []).sorted { $0.order < $1.order },
                viewport: viewport,
                selected: $selectedImage,
                onChange: { item, box in
                    item.rect = box
                    try? context.save()
                    reloadPlaced()
                },
                onDelete: { item in
                    context.delete(item)
                    try? context.save()
                    reloadPlaced()
                }
            )
        }
    }

    private func adoptPlaced(_ item: PhotosPickerItem) async {
        defer { pickedPhoto = nil }
        guard let raw = try? await item.loadTransferable(type: Data.self),
              let source = UIImage(data: raw) else { return }
        insert(source)
    }

    /// Pose une image sur la page.
    ///
    /// Sans point de depot, elle arrive en haut a mi-largeur — de la on la
    /// deplace. Avec, elle se pose centree sous le doigt : c'est tout
    /// l'interet du glisser-deposer, arriver a l'endroit voulu du premier coup.
    @discardableResult
    private func insert(_ source: UIImage, droppedAt viewPoint: CGPoint? = nil) -> Bool {
        // On ne garde jamais l'original : une capture d'ecran de Mac fait
        // plusieurs mega-octets, et la page en porte plusieurs.
        let maxSide: CGFloat = 1_600
        let scale = min(1, maxSide / max(source.size.width, source.size.height))
        let size = CGSize(width: source.size.width * scale, height: source.size.height * scale)
        guard size.width > 0, size.height > 0 else { return false }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let reduced = UIGraphicsImageRenderer(size: size, format: format).image { context in
            context.cgContext.interpolationQuality = .high
            source.draw(in: CGRect(origin: .zero, size: size))
        }

        let made = PageImage(data: reduced.jpegData(compressionQuality: 0.8))
        let ratio = size.height / max(size.width, 1)
        made.width = 0.5
        // La page est haute : une image large occupe peu de hauteur relative.
        made.height = 0.5 * ratio * (PaperBackdrop.pageWidth / PaperBackdrop.pageHeight)
        if let viewPoint, let center = pageFraction(of: viewPoint) {
            // Ramenee dans la page si on l'a lachee pres d'un bord : une image
            // a moitie dehors ne se rattrape qu'a la main.
            made.x = min(max(center.x - made.width / 2, 0), max(0, 1 - made.width))
            made.y = min(max(center.y - made.height / 2, 0), max(0, 1 - made.height))
        } else {
            made.x = 0.25
            made.y = 0.05
        }
        made.order = Double((page.images ?? []).count)
        made.page = page
        context.insert(made)
        try? context.save()
        reloadPlaced()
        // Selectionnee d'emblee : on veut la regler tout de suite, comme
        // partout ailleurs sur iPad.
        selectedImage = made.id
        return true
    }

    /// Un point de l'ecran, en fractions de page.
    ///
    /// Passe par le canevas plutot que par la geometrie de la vue : lui seul
    /// connait le zoom et le defilement, et une image lachee sur une page
    /// zoomee doit tomber la ou on la voit.
    private func pageFraction(of viewPoint: CGPoint) -> CGPoint? {
        let inDrawing = canvasHandle.toDrawing(CGRect(origin: viewPoint, size: .zero))
        guard DrawingCanvas.pageWidth > 0, DrawingCanvas.pageHeight > 0 else { return nil }
        return CGPoint(x: inDrawing.minX / DrawingCanvas.pageWidth,
                       y: inDrawing.minY / DrawingCanvas.pageHeight)
    }

    /// Recoit ce qu'on laisse tomber sur la page.
    private func receiveDrop(_ providers: [NSItemProvider], at location: CGPoint) -> Bool {
        guard let provider = providers.first(where: { $0.canLoadObject(ofClass: UIImage.self) }) else {
            return false
        }
        _ = provider.loadObject(ofClass: UIImage.self) { object, _ in
            guard let image = object as? UIImage else { return }
            Task { @MainActor in insert(image, droppedAt: location) }
        }
        return true
    }

    /// Decode les images une fois : les relire a chaque image du zoom
    /// ferait ramer le stylet.
    private func reloadPlaced() {
        placed = (page.images ?? [])
            .sorted { $0.order < $1.order }
            .compactMap { item in
                guard let data = item.data, let image = UIImage(data: data)?.cgImage else { return nil }
                return PaperBackdrop.Placed(id: item.id, image: image, box: item.rect)
            }
    }

    private func play(_ mark: AudioSync.Mark) {
        guard let recording = (page.recordings ?? []).first(where: { rec in
            rec.strokeTimestamps.contains { $0.strokeID == mark.strokeID }
        }) else { return }
        recorder.play(recording.fileName, from: AudioSync.playbackTime(for: mark))
    }
    #endif
    #if os(iOS)
    /// Pendant l'enregistrement, le chrono reste a l'air libre : c'est la
    /// seule chose qu'on doit pouvoir arreter sans chercher.
    private var recordingChip: some View {
        Button { finishRecording() } label: {
            HStack(spacing: 7) {
                Circle().fill(K.endangered).frame(width: 9, height: 9)
                Text(AudioSync.clock(recorder.elapsed))
                    .font(KFont.mono(11.5))
                    .foregroundStyle(K.paperAlt)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(K.ink, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Arrêter l'enregistrement")
    }

    /// UNE action, celle que la page appelle : masquer sur une diapo,
    /// capturer une carte sur des notes manuscrites.
    @ViewBuilder private var primaryAction: some View {
        if hasBackdrop {
            actionButton(isMasking ? "Terminer" : "Masquer pour réviser", isOn: isMasking) {
                isMasking.toggle()
            }
        } else if !drawing.strokes.isEmpty {
            actionButton(isCapturing ? "Annuler" : "Capturer une carte", isOn: isCapturing) {
                isCapturing.toggle()
            }
        }
    }

    private func actionButton(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(KFont.body(12.5, weight: .extraBold))
                .foregroundStyle(isOn ? K.paperAlt : K.ink)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(isOn ? K.brand : .clear, in: Capsule())
                .overlay(Capsule().strokeBorder(K.ink, lineWidth: 2.5))
        }
        .buttonStyle(.plain)
    }

    /// Tout le reste, range par famille. Un menu se parcourt ; sept boutons
    /// cote a cote se subissent.
    private var pageMenu: some View {
        Menu {
            Menu("Papier") {
                ForEach(PaperKind.allCases, id: \.self) { kind in
                    Button(kind.label) {
                        page.templateRaw = kind.rawValue
                        try? context.save()
                    }
                }
            }
            Button("Ajouter une image") { photoPurpose = .placed; isPickingPhoto = true }
            if CameraPicker.isAvailable {
                Button("Prendre une photo") { isTakingPhoto = true }
            }
            if hasBackdrop {
                Button(isCapturingRegion ? "Annuler la capture" : "Capturer un morceau") {
                    isCapturingRegion.toggle()
                }
            }
            // La proposition de fin de cours ne s'ouvre que dans les 45 min
            // qui suivent un creneau : sans cette entree, une page relue le
            // soir ou sans matiere n'y avait jamais droit.
            Button("Proposer des cartes") { proposeCards() }
                .disabled(cardProposals.isEmpty)

            Divider()

            Menu("Audio") {
                if recorder.isRecording {
                    Button("Arrêter l'enregistrement") { finishRecording() }
                } else {
                    Button("Enregistrer le cours") { Task { await beginRecording() } }
                }
                if hasRecording {
                    Button("Lire depuis le début") { playFromStart() }
                    Button(isListening ? "Quitter l'écoute" : "Écouter en touchant un mot") {
                        isListening.toggle()
                        if !isListening { recorder.stopPlaying() }
                    }
                    Button("Arrêter la lecture") { recorder.stopPlaying() }
                }
            }

            Divider()

            if !courses.isEmpty {
                Menu("Matière") {
                    ForEach(courses) { course in
                        Button(course.name) { assignCourse(course) }
                    }
                    if page.course != nil {
                        Divider()
                        Button("Retirer la matière", role: .destructive) { assignCourse(nil) }
                    }
                }
            }
            Button("Exporter") { exportCurrent() }
        } label: {
            Text("···")
                .font(KFont.body(15, weight: .extraBold))
                .foregroundStyle(K.ink)
                .frame(width: 36, height: 32)
                .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(K.ink, lineWidth: 2.5))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    /// Les cartes que la page donnerait si on les demandait maintenant.
    /// Vide tant que la reconnaissance n'a rien trouve a decouper.
    private var cardProposals: [CardProposer.Proposal] {
        CardProposer.propose(from: page.recognizedText ?? "")
    }

    /// Ouvre les propositions. La palette PencilKit reste au-dessus de tout
    /// tant que le canevas garde le premier repondant : elle recouvrait les
    /// boutons de l'ecran des cartes.
    /// Rend l'ecriture au canevas, si rien d'autre ne la reclame.
    private func resumeWriting() {
        #if os(iOS)
        guard !isCoveredBySheet, !titleFocused, !isMasking else { return }
        canvasHandle.resumeWriting()
        #endif
    }

    private func proposeCards() {
        persist()
        canvasHandle.canvas?.resignFirstResponder()
        // `persist()` LANCE la reconnaissance, il ne l'attend pas. Sans ce
        // `await`, on proposait a partir du texte d'avant — donc rien du tout
        // sur une page qu'on vient d'ecrire, et le bouton avait l'air casse.
        Task {
            await recognitionTask?.value
            onProposeCards(page)
        }
    }


    private func exportCurrent() {
        PDFAssetLookup.remember(assets)
        let siblings = slideSiblings
        Task {
            exportProgress = 0
            let url = await PageExporter.write(
                siblings.isEmpty ? [page] : siblings,
                fallbackName: page.title.isEmpty ? "Page Kurso" : page.title
            ) { value in exportProgress = value }
            exportProgress = nil
            exported = url.map(ExportedFile.init)
        }
    }

    /// La photo est reduite avant d'etre gardee : un cliche d'iPhone pese une
    /// dizaine de megaoctets, et il doit tenir dans l'iCloud de l'etudiant.
    private func adopt(_ item: PhotosPickerItem) async {
        guard let raw = try? await item.loadTransferable(type: Data.self),
              let source = UIImage(data: raw) else { return }
        let maxSide: CGFloat = 2_000
        let scale = min(1, maxSide / max(source.size.width, source.size.height))
        let size = CGSize(width: source.size.width * scale, height: source.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1   // sinon l'ecran Retina double la taille demandee
        let reduced = UIGraphicsImageRenderer(size: size, format: format).image { context in
            context.cgContext.interpolationQuality = .high
            source.draw(in: CGRect(origin: .zero, size: size))
        }
        page.photo = reduced.jpegData(compressionQuality: 0.8)
        try? context.save()
        backdropImage = reduced.cgImage
        pickedPhoto = nil
    }

    #endif

    #if os(iOS)
    /// Decoupe un morceau de la page : le fond ET ce qui est ecrit dessus.
    ///
    /// Le fond est redemande a sa source, jamais agrandi depuis l'apercu :
    /// c'est ce qui permet de garder un schema net meme decoupe petit.
    private func regionImage(_ screenRect: CGRect) -> CGImage? {
        guard screenRect.width > 8, screenRect.height > 8 else { return nil }
        let zoom = max(viewport.zoom, 0.01)
        let pageRect = CGRect(x: -viewport.offset.x, y: -viewport.offset.y,
                              width: PaperBackdrop.pageWidth * zoom,
                              height: PaperBackdrop.pageHeight * zoom)

        // Le meme rectangle, dans le repere de la page.
        let inPage = CGRect(x: (screenRect.minX - pageRect.minX) / zoom,
                            y: (screenRect.minY - pageRect.minY) / zoom,
                            width: screenRect.width / zoom,
                            height: screenRect.height / zoom)

        let pixelWidth = min(max(screenRect.width * 3, 400), 2_400)
        let size = CGSize(width: pixelWidth,
                          height: pixelWidth * screenRect.height / screenRect.width)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1   // sinon l'ecran Retina double la taille demandee
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            if let source = backdropImage {
                let fitted = PaperBackdrop.placement(
                    image: CGSize(width: source.width, height: source.height),
                    box: page.photoRect, in: pageRect)
                let visible = fitted.intersection(screenRect)
                if !visible.isNull, fitted.width > 0, fitted.height > 0 {
                    let crop = CGRect(x: (visible.minX - fitted.minX) / fitted.width,
                                      y: (visible.minY - fitted.minY) / fitted.height,
                                      width: visible.width / fitted.width,
                                      height: visible.height / fitted.height)
                    if let piece = backdropCrop(crop, pixelWidth: Int(pixelWidth)) {
                        // Replace le morceau la ou il tombe dans la selection.
                        let scale = size.width / screenRect.width
                        let target = CGRect(x: (visible.minX - screenRect.minX) * scale,
                                            y: (visible.minY - screenRect.minY) * scale,
                                            width: visible.width * scale,
                                            height: visible.height * scale)
                        UIImage(cgImage: piece).draw(in: target)
                    }
                }
            }

            // L'ecriture par-dessus, a la meme echelle.
            if !drawing.strokes.isEmpty {
                drawing.image(from: inPage, scale: size.width / inPage.width)
                    .draw(in: CGRect(origin: .zero, size: size))
            }
        }.cgImage
    }

    /// Le fond, redemande a sa source pour la portion voulue.
    private func backdropCrop(_ crop: CGRect, pixelWidth: Int) -> CGImage? {
        if page.pdfAssetID == nil, let source = backdropImage {
            // Une photo : on decoupe dans l'image deja chargee.
            let rect = CGRect(x: crop.minX * CGFloat(source.width),
                              y: crop.minY * CGFloat(source.height),
                              width: crop.width * CGFloat(source.width),
                              height: crop.height * CGFloat(source.height))
            return source.cropping(to: rect.integral)
        }
        guard let name = pdfFileName, let index = page_pdfIndex else { return nil }
        return PDFStore.render(fileName: name, pageIndex: index,
                               crop: crop, pixelWidth: pixelWidth)
    }
    #endif

    /// Un fond existe : diapo de PDF, ou photo posee par l'etudiant. Les deux
    /// se masquent et s'annotent de la meme facon.
    private var hasBackdrop: Bool { page.pdfAssetID != nil || page.photo != nil }

    /// Ranger une diapo range TOUT le PDF.
    ///
    /// Un polycopie appartient a une matiere entiere : classer page par page
    /// n'aurait aucun sens, et laissait les autres diapos orphelines.
    private func assignCourse(_ course: Course?) {
        let siblings = slideSiblings
        for target in siblings.isEmpty ? [page] : siblings {
            target.course = course
        }
        try? context.save()
    }

    private var slideSiblings: [Page] {
        guard let asset = page.pdfAssetID else { return [] }
        return allPages
            .filter { $0.pdfAssetID == asset }
            .sorted { ($0.pdfPageIndex ?? 0) < ($1.pdfPageIndex ?? 0) }
    }

    private func jump(to siblings: [Page], _ index: Int) {
        guard siblings.indices.contains(index) else { return }
        persist()
        onOpenSlide(siblings[index])
    }

    @ViewBuilder private var coursePicker: some View {
        if !courses.isEmpty {
            Menu {
                ForEach(courses) { course in
                    Button(course.name) { assignCourse(course) }
                }
                if page.course != nil {
                    Divider()
                    Button("Retirer la matière", role: .destructive) {
                        assignCourse(nil)
                        try? context.save()
                    }
                }
            } label: {
                HStack(spacing: 7) {
                    if let course = page.course {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(K.brand)
                            .frame(width: 9, height: 9)
                        Text(course.name)
                            .font(KFont.body(12.5, weight: .extraBold))
                            .foregroundStyle(K.ink)
                    } else {
                        Text("Choisir une matière")
                            .font(KFont.body(12.5, weight: .bold))
                            .foregroundStyle(K.inkSoft)
                    }
                    ChevronGlyph()
                        .stroke(K.inkSoft, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                        .frame(width: 8, height: 8)
                        .rotationEffect(.degrees(-90))
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
                .overlay(Capsule().strokeBorder(K.ink, lineWidth: 2.5))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }

    /// Le trace est deja charge par l'initialiseur ; il ne reste que le
    /// compteur d'ecriture, qui n'a aucune incidence sur les donnees.
    private func load() {
        clock = WritingClock(accumulatedSeconds: page.writingSeconds)
        displayedSeconds = page.writingSeconds
    }

    #if os(iOS)
    /// Re-rend la portion visible de la diapo apres un zoom.
    ///
    /// Jamais la page entiere : a 5x un A4 demanderait pres de 900 Mo. Ne
    /// rendre que le visible garde un cout constant, quel que soit le zoom.
    private func scheduleTile() {
        guard let base = backdropImage, viewport.size != .zero else { return }
        tileTask?.cancel()

        // En dessous de ce seuil, l'image de base est deja plus fine que
        // l'ecran : une tuile n'apporterait rien.
        guard viewport.zoom > 1.2 else { backdropTile = nil; return }

        let page = CGRect(x: -viewport.offset.x, y: -viewport.offset.y,
                          width: DrawingCanvas.pageWidth * viewport.zoom,
                          height: DrawingCanvas.pageHeight * viewport.zoom)
        let fitted = PaperBackdrop.placement(
            image: CGSize(width: base.width, height: base.height),
            box: self.page.photoRect, in: page)
        let visible = fitted.intersection(CGRect(origin: .zero, size: viewport.size))
        guard !visible.isNull, visible.width > 8, visible.height > 8 else { return }

        let crop = CGRect(x: (visible.minX - fitted.minX) / fitted.width,
                          y: (visible.minY - fitted.minY) / fitted.height,
                          width: visible.width / fitted.width,
                          height: visible.height / fitted.height)
        // Plafonne : au-dela, c'est de la memoire depensee pour rien.
        let pixels = min(Int(visible.width * displayScale), 4_096)
        let name = pdfFileName
        let index = page_pdfIndex

        tileTask = Task {
            // On laisse le geste se terminer : re-rendre a chaque image du
            // pincement ne servirait qu'a chauffer l'appareil.
            try? await Task.sleep(for: .milliseconds(160))
            guard !Task.isCancelled, let name, let index else { return }
            let rendered = await Task.detached(priority: .userInitiated) {
                PDFStore.render(fileName: name, pageIndex: index, crop: crop, pixelWidth: pixels)
            }.value
            guard !Task.isCancelled, let rendered else { return }
            backdropTile = PaperBackdrop.Tile(image: rendered, crop: crop)
        }
    }

    /// Nom de fichier de la diapo, ou le PDF d'essai en debogage.
    private var pdfFileName: String? {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-fakePDF") { return "test-diapo.pdf" }
        #endif
        return pdfAsset?.fileName
    }

    private var page_pdfIndex: Int? {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-fakePDF") { return 0 }
        #endif
        return page.pdfPageIndex
    }

    private func loadPDF() async {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-fakePDF") {
            Self.installTestPDF()
            // La page de demo n'a pas de diapo : on lui en attache une, sans
            // quoi les ecrans qui en dependent ne s'affichent pas.
            if page.pdfPageIndex == nil { page.pdfPageIndex = 0 }
        }
        #endif
        // Une photo posee sur la page tient lieu de fond, comme une diapo.
        if page.pdfAssetID == nil, let data = page.photo {
            backdropImage = UIImage(data: data)?.cgImage
            return
        }
        guard let fileName = pdfFileName, let index = page_pdfIndex else { return }
        // La largeur est lue ici, sur l'acteur principal, avant de partir en
        // tache detachee.
        let width = DrawingCanvas.pageWidth * 2
        let rendered = await Task.detached(priority: .userInitiated) {
            PDFStore.render(fileName: fileName, pageIndex: index, width: width)
        }.value
        backdropImage = rendered
    }
    #endif

    #if DEBUG && os(iOS)
    /// Depose le PDF d'essai dans le conteneur, pour verifier le vrai chemin
    /// de rendu — orientation comprise.
    private static func installTestPDF() {
        let destination = PDFStore.url(for: "test-diapo.pdf")
        guard !FileManager.default.fileExists(atPath: destination.path) else { return }
        try? FileManager.default.copyItem(at: URL(filePath: "/tmp/test-diapo.pdf"), to: destination)
    }
    #endif

    private func persist(_ latest: PKDrawing? = nil) {
        guard !loadFailed else { return }
        // Ordre de confiance : le trace passe en argument, sinon celui du
        // canevas vivant, et l'etat SwiftUI seulement en dernier recours.
        #if os(iOS)
        let live = canvasHandle.currentDrawing
        let toSave = latest ?? live ?? drawing
        let source = latest != nil ? "argument" : (live != nil ? "canevas" : "etat")
        #else
        let toSave = latest ?? drawing
        let source = latest != nil ? "argument" : "etat"
        #endif

        // Un enregistrement sans argument vient d'un demontage de vue, pas
        // d'un geste : il n'a pas le droit de vider la page (§DrawingSaveGuard).
        let storedStrokes = (page.drawing.flatMap { try? PKDrawing(data: $0) })?.strokes.count ?? 0
        guard DrawingSaveGuard.shouldWrite(incomingStrokes: toSave.strokes.count,
                                           storedStrokes: storedStrokes,
                                           origin: latest != nil ? .gesture : .teardown) else {
            #if DEBUG
            print("[KURSO] enregistrement vide refuse (\(storedStrokes) traits conserves)")
            #endif
            return
        }
        let before = page.writingSeconds
        page.writingSeconds = clock.seconds(now: .now)
        // Une page compte pour la quete des qu'elle passe dix minutes d'ecriture
        // reelle, et une seule fois.
        if before < GameValues.writtenPageSeconds, page.writingSeconds >= GameValues.writtenPageSeconds {
            DailyActivityStore.record(.writePage, context: context)
            PlayerStore.award(shavings: Shop.Earn.finishedPage, context: context)
        }
        displayedSeconds = page.writingSeconds
        page.drawing = toSave.dataRepresentation()
        do { try context.save() }
        catch {
            #if DEBUG
            print("[KURSO] ECHEC ENREGISTREMENT: \(error)")
            #endif
        }
        #if DEBUG
        print("[KURSO] persist traits=\(toSave.strokes.count) octets=\(page.drawing?.count ?? 0) source=\(source)")
        #endif
        scheduleRecognition(toSave)
    }

    /// La reconnaissance tourne apres l'enregistrement, jamais pendant l'ecriture :
    /// Vision sur une page entiere prend le temps qu'il faut, et rien ne doit
    /// disputer le fil principal au stylet.
    private func scheduleRecognition(_ snapshot: PKDrawing) {
        recognitionTask?.cancel()
        recognitionTask = Task {
            let text = await HandwritingRecognizer.recognize(snapshot)
            guard !Task.isCancelled, !text.isEmpty else { return }
            await MainActor.run {
                page.recognizedText = text
                // §4 : la premiere ligne reconnue fait le titre, sauf si
                // l'etudiant l'a edite — on n'y retouche alors plus jamais.
                if !page.titleWasEdited, page.markdown.isEmpty,
                   let derived = PageTitle.derive(from: text) {
                    page.title = derived
                }
                try? context.save()
            }
        }
    }
}

#if os(iOS)
/// Enveloppe identifiable pour un morceau de page decoupe.
struct ImageDraft: Identifiable {
    let id = UUID()
    let image: CGImage
}
#endif

/// Enveloppe identifiable, pour presenter la saisie de question en feuille.
struct CaptureDraft: Identifiable {
    let id = UUID()
    let drawing: PKDrawing
}
