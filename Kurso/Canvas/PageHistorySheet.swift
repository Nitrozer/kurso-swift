#if os(iOS)
import SwiftUI
import PencilKit
import KursoCore
import KursoModels

/// Revenir en arriere sur une page.
///
/// On montre le TRACE de chaque etat, pas sa date seule : « hier 18:42 » ne
/// dit pas ce qu'on y retrouvera, une vignette si.
struct PageHistorySheet: View {
    let page: Page
    var onRestore: (PageSnapshot) -> Void
    var onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                DisplayText("Revenir en arrière", size: 24)
                Spacer(minLength: 0)
                Button("Fermer", action: onClose)
                    .buttonStyle(.plain)
                    .font(KFont.body(12.5, weight: .extraBold))
                    .foregroundStyle(K.inkSoft)
            }

            if states.isEmpty {
                Text("Rien à restaurer pour l'instant. Kurso retient l'état de la page au fil de l'écriture, au plus une fois toutes les 20 minutes.")
                    .font(KFont.body(13, weight: .bold))
                    .foregroundStyle(K.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 14)], spacing: 14) {
                        ForEach(states, id: \.id) { snapshot in
                            Button { onRestore(snapshot) } label: { card(snapshot) }
                                .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
            }

            Text("Restaurer garde d'abord l'état actuel : on peut toujours revenir sur ses pas. Ceci n'est pas une sauvegarde — cela vit dans l'application et disparaît avec elle.")
                .font(KFont.body(11, weight: .bold))
                .foregroundStyle(K.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(K.paper)
    }

    /// Du plus recent au plus ancien : c'est presque toujours l'avant-dernier
    /// etat qu'on cherche.
    private var states: [PageSnapshot] {
        (page.snapshots ?? []).sorted { $0.takenAt > $1.takenAt }
    }

    private func card(_ snapshot: PageSnapshot) -> some View {
        VStack(spacing: 6) {
            ZStack {
                DottedPaper()
                if let image = ink(snapshot) {
                    Image(uiImage: image).resizable().scaledToFit().padding(5)
                }
            }
            .frame(width: 132, height: 174)
            .background(K.paperAlt)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(K.ink.opacity(0.22), lineWidth: 1.5))

            Text(PageHistory.label(snapshot.takenAt))
                .font(KFont.body(11.5, weight: .extraBold))
                .foregroundStyle(K.ink)
            Text("\(snapshot.strokeCount) trait\(snapshot.strokeCount > 1 ? "s" : "")")
                .font(KFont.mono(9.5))
                .foregroundStyle(K.inkSoft)
        }
    }

    private func ink(_ snapshot: PageSnapshot) -> UIImage? {
        guard let data = snapshot.drawing, let drawing = try? PKDrawing(data: data),
              !drawing.bounds.isEmpty else { return nil }
        return drawing.image(from: drawing.bounds, scale: 1)
    }
}
#endif
