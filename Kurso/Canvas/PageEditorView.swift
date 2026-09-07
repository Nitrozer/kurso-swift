import SwiftUI
import SwiftData
import PencilKit
import KursoCore
import KursoModels

/// Editeur d'une page. Sur iPad, le canevas PencilKit ; sur Mac, un ecran
/// d'attente en attendant le volet markdown (§11, etape 1).
struct PageEditorView: View {
    @Bindable var page: Page
    @Environment(\.modelContext) private var context

    @State private var drawing = PKDrawing()
    @State private var clock = WritingClock()
    /// Affiche le temps d'ecriture reel, pas le temps d'ecran.
    @State private var displayedSeconds = 0
    @State private var loadFailed = false

    var body: some View {
        VStack(spacing: 0) {
            header

            #if os(iOS)
            DrawingCanvas(
                drawing: $drawing,
                onBeginWriting: { clock.begin(at: .now) },
                onEndWriting: {
                    clock.end(at: .now)
                    persist()
                }
            )
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
        .task { load() }
        .onDisappear { persist() }
    }

    private var header: some View {
        HStack {
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
    }
}
