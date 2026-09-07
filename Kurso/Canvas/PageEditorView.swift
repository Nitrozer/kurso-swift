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

    @State private var drawing = PKDrawing()
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
                onEndWriting: {
                    clock.end(at: .now)
                    persist()
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
            Button(action: onClose) {
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

    private func load() {
        clock = WritingClock(accumulatedSeconds: page.writingSeconds)
        displayedSeconds = page.writingSeconds
        guard let data = page.drawing, !data.isEmpty else { return }
        do {
            drawing = try PKDrawing(data: data)
        } catch {
            // On n'ecrase pas : sans ce garde-fou, enregistrer par-dessus
            // remplacerait un dessin existant par une page vide.
            loadFailed = true
        }
    }

    private func persist() {
        guard !loadFailed else { return }
        page.writingSeconds = clock.seconds(now: .now)
        displayedSeconds = page.writingSeconds
        page.drawing = drawing.dataRepresentation()
        try? context.save()
        scheduleRecognition()
    }

    /// La reconnaissance tourne apres l'enregistrement, jamais pendant l'ecriture :
    /// Vision sur une page entiere prend le temps qu'il faut, et rien ne doit
    /// disputer le fil principal au stylet.
    private func scheduleRecognition() {
        recognitionTask?.cancel()
        let snapshot = drawing
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
