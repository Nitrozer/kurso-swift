import SwiftUI

/// Etat vide, en autocollant.
///
/// Remplace `ContentUnavailableView` : ce composant Apple se reconnait au premier
/// coup d'oeil et porte une icone de bibliotheque, deux choses que la direction
/// artistique refuse. On s'en tient au texte et a la forme.
struct EmptyState: View {
    let title: String
    var message: String? = nil

    var body: some View {
        VStack(spacing: 10) {
            DisplayText(title, size: 20)
            if let message {
                Text(message)
                    .font(KFont.body(13.5, weight: .bold))
                    .foregroundStyle(K.inkSoft)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
            }
        }
        .padding(22)
        .frame(maxWidth: 340)
        .sticker(fill: K.paperAlt, radius: 18, state: .upcoming)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}
