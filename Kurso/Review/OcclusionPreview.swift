import SwiftUI

/// Une diapo dont une zone est couverte tant qu'on n'a pas repondu.
///
/// Le rectangle est enregistre en fractions de la diapo : il retombe donc au
/// bon endroit quelle que soit la taille a laquelle on l'affiche.
struct OcclusionPreview: View {
    let image: CGImage
    let hidden: CGRect?
    let isRevealed: Bool

    var body: some View {
        Image(decorative: image, scale: 1)
            .resizable()
            .scaledToFit()
            .overlay(alignment: .topLeading) { cover }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder private var cover: some View {
        if let hidden, !isRevealed {
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(K.reward)
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(K.ink, lineWidth: 2.5))
                    .frame(width: hidden.width * geo.size.width,
                           height: hidden.height * geo.size.height)
                    .offset(x: hidden.minX * geo.size.width,
                            y: hidden.minY * geo.size.height)
            }
        }
    }
}
