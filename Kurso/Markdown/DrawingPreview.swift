import SwiftUI
import PencilKit

/// Rendu du manuscrit en image.
///
/// Le SDK macOS ne fournit pas `PKCanvasView`, mais il fournit
/// `PKDrawing.image(from:scale:)` — qui rend une `NSImage` sur Mac et une
/// `UIImage` sur iOS. C'est ce qui permet de relire ses notes manuscrites sur
/// Mac a cote du volet markdown, sans pouvoir les modifier.
struct DrawingPreview: View {
    let drawing: PKDrawing
    var scale: CGFloat = 2

    var body: some View {
        if drawing.bounds.isEmpty {
            EmptyState(title: "Page vierge", message: "Rien n'a encore été écrit sur cette page.")
        } else {
            ScrollView([.horizontal, .vertical]) {
                image
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .padding(20)
            }
            .background(K.paper)
        }
    }

    private var image: Image {
        let rendered = drawing.image(from: drawing.bounds, scale: scale)
        #if canImport(UIKit)
        return Image(uiImage: rendered)
        #else
        return Image(nsImage: rendered)
        #endif
    }
}
