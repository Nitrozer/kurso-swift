import SwiftUI
import SwiftData
import PencilKit
import KursoCore
import KursoModels

/// Editeur d'une page. Sur iPad, le canevas PencilKit ; sur Mac, un ecran
/// d'attente en attendant le volet markdown (§11, etape 1).
struct PageEditorView: View {
    @Bindable var page: Page
    var onClose: () -> Void = {}
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
    #if os(iOS)
    @State private var canvasHandle = CanvasHandle()
    #endif
    @Query private var assets: [PDFAsset]
    @Query(sort: \Course.name) private var courses: [Course]

    /// Le trace est lu ICI, avant que la vue existe.
    ///
    /// Le charger plus tard laissait une fenetre ou le canevas etait construit
    /// vide : PencilKit signalait ce vide comme un changement, on l'enregistrait
    /// par-dessus la page, et le travail etait perdu a la simple ouverture.
    init(page: Page, onClose: @escaping () -> Void = {}) {
        _page = Bindable(page)
        self.onClose = onClose
        let stored = page.drawing
        let hasStored = !(stored ?? Data()).isEmpty
        let loaded = hasStored ? try? PKDrawing(data: stored!) : PKDrawing()
        _drawing = State(initialValue: loaded ?? PKDrawing())
        // On n'ecrase pas ce qu'on n'a pas su relire.
        _loadFailed = State(initialValue: hasStored && loaded == nil)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            #if os(iOS)
            HStack(spacing: 0) {
            ZStack {
                if let asset = pdfAsset, let index = page.pdfPageIndex {
                    PDFBackground(asset: asset, pageIndex: index)
                        .padding(8)
                }
                DrawingCanvas(
                drawing: $drawing,
                onBeginWriting: { clock.begin(at: .now) },
                onEndWriting: { latest in
                    clock.end(at: .now)
                    drawing = latest
                    persist(latest)
                }
            )
                if isMasking, let index = page.pdfPageIndex {
                    OcclusionLayer(page: page, pageIndex: index) { isMasking = false }
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
        .task { load() }
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
                DisplayText(page.title.isEmpty ? "Page sans titre" : page.title, size: 19)
                MetaText(page.createdAt.formatted(.dateTime.weekday(.wide).day().month(.wide)))
            }
            coursePicker
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
            } else if page.pdfAssetID != nil {
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
    @ViewBuilder private var coursePicker: some View {
        if !courses.isEmpty {
            Menu {
                ForEach(courses) { course in
                    Button(course.name) {
                        page.course = course
                        try? context.save()
                    }
                }
                if page.course != nil {
                    Divider()
                    Button("Retirer la matière", role: .destructive) {
                        page.course = nil
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

    private func persist(_ latest: PKDrawing? = nil) {
        guard !loadFailed else { return }
        // Ordre de confiance : le trace passe en argument, sinon celui du
        // canevas vivant, et l'etat SwiftUI seulement en dernier recours.
        #if os(iOS)
        let toSave = latest ?? canvasHandle.currentDrawing ?? drawing
        #else
        let toSave = latest ?? drawing
        #endif
        let before = page.writingSeconds
        page.writingSeconds = clock.seconds(now: .now)
        // Une page compte pour la quete des qu'elle passe dix minutes d'ecriture
        // reelle, et une seule fois.
        if before < GameValues.writtenPageSeconds, page.writingSeconds >= GameValues.writtenPageSeconds {
            DailyActivityStore.record(.writePage, context: context)
        }
        displayedSeconds = page.writingSeconds
        page.drawing = toSave.dataRepresentation()
        try? context.save()
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

/// Enveloppe identifiable, pour presenter la saisie de question en feuille.
struct CaptureDraft: Identifiable {
    let id = UUID()
    let drawing: PKDrawing
}
