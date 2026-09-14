import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers
import PencilKit
import KursoCore
import KursoModels

/// Editeur d'une page. Sur iPad, le canevas PencilKit ; sur Mac, un ecran
/// d'attente en attendant le volet markdown (§11, etape 1).
struct PageEditorView: View {
    @Bindable var page: Page
    var onClose: () -> Void = {}
    /// Ouvre une autre diapo du meme PDF.
    var onOpenSlide: (Page) -> Void = { _ in }
    @Environment(\.modelContext) private var context

    @State private var drawing: PKDrawing
    @State private var clock = WritingClock()
    /// Affiche le temps d'ecriture reel, pas le temps d'ecran.
    @State private var displayedSeconds = 0
    @State private var loadFailed = false
    @State private var recognitionTask: Task<Void, Never>?
    @State private var isMasking = false
    @State private var isCapturing = false
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
         onOpenSlide: @escaping (Page) -> Void = { _ in }) {
        _page = Bindable(page)
        self.onClose = onClose
        self.onOpenSlide = onOpenSlide
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
                    template: .ruled,
                    pageSize: CGSize(width: DrawingCanvas.pageWidth,
                                     height: DrawingCanvas.pageHeight),
                    backdrop: backdropImage,
                    backdropTile: backdropTile,
                    backdropBox: page.photoRect
                )
                DrawingCanvas(
                drawing: $drawing,
                handle: canvasHandle,
                onViewportChange: { viewport = $0 },
                onBeginWriting: { clock.begin(at: .now) },
                onEndWriting: { latest in
                    clock.end(at: .now)
                    drawing = latest
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
            TaskMargin(page: page)
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
            // Rejoue le geste complet : on ecrit, puis on appuie sur retour.
            if ProcessInfo.processInfo.arguments.contains("-simulateBack") {
                try? await Task.sleep(for: .seconds(6))
                print("[KURSO] --- appui sur retour ---")
                persist()
                onClose()
            }
            #endif
        }
        #if os(iOS)
        // Le champ du titre prend le premier repondant, et la palette
        // PencilKit disparait avec. On la rend des qu'on quitte le champ.
        .onChange(of: titleFocused) { _, focused in
            if !focused { canvasHandle.canvas?.becomeFirstResponder() }
        }
        .onChange(of: isMasking) { _, masking in
            if !masking { canvasHandle.canvas?.becomeFirstResponder() }
        }
        #endif
        #if os(iOS)
        .sheet(item: $exported) { ShareSheet(url: $0.url) }
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
        .onDisappear {
            persist()
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Button {
                // Enregistrer AVANT de fermer : onDisappear arrive trop tard,
                // la vue est deja demontee et son canevas avec.
                persist()
                onClose()
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

            VStack(alignment: .leading, spacing: 3) {
                // Modifiable au clavier. Tant qu'on n'y touche pas, c'est la
                // premiere ligne reconnue qui nomme la page (§4) — d'ou le
                // drapeau, qui empeche la reconnaissance d'ecraser un choix.
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
                .frame(minWidth: 120, idealWidth: 240, maxWidth: 320, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                MetaText(page.createdAt.formatted(.dateTime.weekday(.wide).day().month(.wide)))
            }
            #if os(iOS)
            exportButton
            addPDFButton
            photoButton
            adjustPhotoButton
            #endif
            coursePicker
            slideNav
            Spacer()
            if loadFailed {
                // Un dessin illisible ne doit jamais etre ecrase en silence (§8).
                Text("DESSIN ILLISIBLE")
                    .font(KFont.mono(10))
                    .tracking(1.2)
                    .foregroundStyle(K.paperAlt)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 5)
                    .background(K.alertBg, in: Capsule())
                    .overlay(Capsule().strokeBorder(K.ink, lineWidth: 2.5))
            } else if !drawing.strokes.isEmpty && page.pdfAssetID == nil {
                Button { isCapturing.toggle() } label: {
                    Text(isCapturing ? "Annuler" : "Capturer une carte")
                        .font(KFont.body(12, weight: .extraBold))
                        .foregroundStyle(isCapturing ? K.paperAlt : K.ink)
                        .padding(.horizontal, 13).padding(.vertical, 7)
                        .background(isCapturing ? K.brand : .clear, in: Capsule())
                        .overlay(Capsule().strokeBorder(K.ink, lineWidth: 2.5))
                }
                .buttonStyle(.plain)
            } else if hasBackdrop {
                #if os(iOS)
                Button { isCapturingRegion.toggle() } label: {
                    Text(isCapturingRegion ? "Annuler" : "Capturer une image")
                        .font(KFont.body(12, weight: .extraBold))
                        .foregroundStyle(isCapturingRegion ? K.paperAlt : K.ink)
                        .padding(.horizontal, 13).padding(.vertical, 7)
                        .background(isCapturingRegion ? K.brand : .clear, in: Capsule())
                        .overlay(Capsule().strokeBorder(K.ink, lineWidth: 2.5))
                }
                .buttonStyle(.plain)
                #endif
                Button { isMasking.toggle() } label: {
                    Text(isMasking ? "Terminer" : "Masquer pour réviser")
                        .font(KFont.body(12, weight: .extraBold))
                        .foregroundStyle(isMasking ? K.paperAlt : K.ink)
                        .padding(.horizontal, 13).padding(.vertical, 7)
                        .background(isMasking ? K.brand : .clear, in: Capsule())
                        .overlay(Capsule().strokeBorder(K.ink, lineWidth: 2.5))
                }
                .buttonStyle(.plain)
            } else {
                MetaText("\(displayedSeconds / 60) MIN D'ECRITURE")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(K.paper)
        .overlay(alignment: .bottom) {
            Rectangle().fill(K.ink).frame(height: 3)
        }
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

    /// Un fond existe : diapo de PDF, ou photo posee par l'etudiant. Les deux
    /// se masquent et s'annotent de la meme facon.
    private var hasBackdrop: Bool { page.pdfAssetID != nil || page.photo != nil }

    #if os(iOS)
    @ViewBuilder private var adjustPhotoButton: some View {
        if page.photo != nil {
            Button { isAdjustingPhoto.toggle() } label: {
                Text(isAdjustingPhoto ? "Terminer" : "Régler l'image")
                    .font(KFont.body(12, weight: .extraBold))
                    .foregroundStyle(isAdjustingPhoto ? K.paperAlt : K.ink)
                    .padding(.horizontal, 13).padding(.vertical, 7)
                    .background(isAdjustingPhoto ? K.brand : .clear, in: Capsule())
                    .overlay(Capsule().strokeBorder(K.ink, lineWidth: 2.5))
            }
            .buttonStyle(.plain)
        }
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

    /// Deposer des diapos dans le meme cahier que cette note.
    ///
    /// Un cahier melange l'ecrit et le polycopie : c'est comme ca qu'on
    /// travaille en cours, pas en separant les deux.
    private var addPDFButton: some View {
        Button { isPickingPDF = true } label: {
            Text("Ajouter un PDF")
                .font(KFont.body(12, weight: .extraBold))
                .foregroundStyle(K.ink)
                .padding(.horizontal, 13).padding(.vertical, 7)
                .overlay(Capsule().strokeBorder(K.ink, lineWidth: 2.5))
        }
        .buttonStyle(.plain)
    }

    private var exportButton: some View {
        Button {
            PDFAssetLookup.remember(assets)
            // Un PDF s'exporte en entier : une diapo isolee ne veut rien dire.
            let siblings = slideSiblings
            exported = PageExporter.write(siblings.isEmpty ? [page] : siblings,
                                          fallbackName: page.title.isEmpty ? "Page Kurso" : page.title)
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

    @ViewBuilder private var photoButton: some View {
        if page.pdfAssetID == nil {
            PhotosPicker(selection: $pickedPhoto, matching: .images, photoLibrary: .shared()) {
                Text(page.photo == nil ? "Ajouter une photo" : "Changer la photo")
                    .font(KFont.body(12, weight: .extraBold))
                    .foregroundStyle(K.ink)
                    .padding(.horizontal, 13).padding(.vertical, 7)
                    .overlay(Capsule().strokeBorder(K.ink, lineWidth: 2.5))
            }
            .buttonStyle(.plain)
            .onChange(of: pickedPhoto) { _, item in
                guard let item else { return }
                Task { await adopt(item) }
            }
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
