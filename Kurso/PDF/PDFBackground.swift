import SwiftUI
import KursoModels

/// La diapo, sous le canevas.
///
/// Rendue a la largeur affichee et mise en cache : re-rendre a chaque image
/// ferait ramer le stylet, ce qui est la seule chose qu'on ne peut pas se
/// permettre pendant un cours.
struct PDFBackground: View {
    let asset: PDFAsset
    let pageIndex: Int

    @State private var image: CGImage?
    @State private var renderedWidth: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            Group {
                if let image {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .scaledToFit()
                } else {
                    Color.clear
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .task(id: geo.size.width) {
                await render(width: geo.size.width)
            }
        }
    }

    private func render(width: CGFloat) async {
        guard width > 0, abs(width - renderedWidth) > 1 else { return }
        let fileName = asset.fileName
        let index = pageIndex
        // Hors du fil principal : rasteriser une diapo A4 prend le temps qu'il faut.
        let rendered = await Task.detached(priority: .userInitiated) {
            PDFStore.render(fileName: fileName, pageIndex: index, width: width * 2)
        }.value
        await MainActor.run {
            image = rendered
            renderedWidth = width
        }
    }
}
