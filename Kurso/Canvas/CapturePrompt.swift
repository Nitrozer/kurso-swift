import SwiftUI
import SwiftData
import PencilKit
import KursoModels

/// Saisie de la question, apres avoir entoure le verso.
///
/// Seule la question se tape : le verso reste le trace manuscrit, tel quel.
struct CapturePrompt: View {
    let page: Page
    var answer: PKDrawing = PKDrawing()
    /// Un morceau de diapo ou de photo, quand le verso n'est pas manuscrit.
    var image: CGImage?
    var onDone: () -> Void

    @Environment(\.modelContext) private var context
    @State private var question = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                MetaText("Nouvelle carte")
                DisplayText("Qu'est-ce que tu veux qu'on te demande ?", size: 22)
            }

            preview

            TextField("Ex. : complexité de l'insertion dans un tas", text: $question)
                .textFieldStyle(.plain)
                .font(KFont.body(14, weight: .bold))
                .foregroundStyle(K.ink)
                .padding(14)
                .sticker(fill: K.paperAlt, radius: 14, state: .done)

            HStack(spacing: 12) {
                Button("Annuler") { onDone() }
                    .buttonStyle(StickerButtonStyle(kind: .secondary))
                Button("Créer la carte") { create() }
                    .buttonStyle(StickerButtonStyle(kind: .primary))
                    .disabled(question.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(26)
        .frame(maxWidth: 520)
        .background(K.paper)
    }

    /// Le verso, montre tel qu'il sera garde.
    @ViewBuilder private var preview: some View {
        if let image {
            Image(decorative: image, scale: 1)
                .resizable().scaledToFit().frame(maxHeight: 160)
                .padding(12).frame(maxWidth: .infinity)
                .sticker(fill: K.paperAlt, radius: 14)
        } else if !answer.bounds.isEmpty {
            let image = answer.image(from: answer.bounds, scale: 2)
            #if canImport(UIKit)
            Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 120)
                .padding(12).frame(maxWidth: .infinity)
                .sticker(fill: K.paperAlt, radius: 14)
            #else
            Image(nsImage: image).resizable().scaledToFit().frame(maxHeight: 120)
                .padding(12).frame(maxWidth: .infinity)
                .sticker(fill: K.paperAlt, radius: 14)
            #endif
        }
    }

    private func create() {
        let card = Card(question: question.trimmingCharacters(in: .whitespaces), kind: .frontBack, dueAt: .now)
        if let image {
            #if canImport(UIKit)
            card.imageData = UIImage(cgImage: image).jpegData(compressionQuality: 0.8)
            #endif
        } else {
            // Le trace, pas une transcription : « inser° » reste « inser° » (§4).
            card.answerDrawing = answer.dataRepresentation()
        }
        card.page = page
        context.insert(card)
        DailyActivityStore.record(.captureCard, context: context)
        try? context.save()
        onDone()
    }
}
