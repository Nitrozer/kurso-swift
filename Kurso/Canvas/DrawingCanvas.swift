#if os(iOS)
import SwiftUI
import PencilKit

/// Le canevas d'ecriture. iOS uniquement : le SDK macOS fournit les types
/// PencilKit (PKDrawing, PKStroke) mais pas `PKCanvasView`. Sur Mac, une page
/// s'affiche et s'annote en markdown — c'est ce que prevoit le §11.
/// Donne acces au canevas vivant.
///
/// La capture doit convertir des coordonnees de vue en coordonnees de dessin,
/// ce qui demande le defilement et le zoom courants — deux choses que seule la
/// vue connait.
@Observable final class CanvasHandle {
    weak var canvas: PKCanvasView?

    /// Convertit un rectangle de la vue vers l'espace du dessin.
    func toDrawing(_ rect: CGRect) -> CGRect {
        guard let canvas else { return rect }
        let zoom = max(canvas.zoomScale, 0.01)
        let offset = canvas.contentOffset
        return CGRect(
            x: (rect.minX + offset.x) / zoom,
            y: (rect.minY + offset.y) / zoom,
            width: rect.width / zoom,
            height: rect.height / zoom
        )
    }
}

struct DrawingCanvas: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    var handle: CanvasHandle?
    /// Le stylet touche la surface.
    var onBeginWriting: () -> Void
    /// Le stylet quitte la surface : c'est aussi le moment ou l'on enregistre.
    var onEndWriting: () -> Void

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.delegate = context.coordinator
        canvas.drawing = drawing

        // `.default` plutot que `.pencilOnly` en dur : PencilKit choisit seul —
        // stylet exclusif des qu'un Apple Pencil a ete appaire, doigt accepte
        // sinon. On garde donc le comportement « le doigt fait defiler, le stylet
        // ecrit » sur un vrai iPad, sans rendre le canevas inutilisable au
        // simulateur ni sur un iPad sans stylet.
        canvas.drawingPolicy = .default

        canvas.alwaysBounceVertical = true
        canvas.backgroundColor = .clear
        canvas.isOpaque = false

        context.coordinator.attachToolPicker(to: canvas)
        handle?.canvas = canvas
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        // Ne reinjecter que si le modele a change ailleurs : reaffecter le dessin
        // pendant que l'utilisateur ecrit interromprait son trait.
        if canvas.drawing != drawing && !context.coordinator.isWriting {
            canvas.drawing = drawing
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        private let parent: DrawingCanvas
        private var toolPicker: PKToolPicker?
        private(set) var isWriting = false

        init(_ parent: DrawingCanvas) { self.parent = parent }

        func attachToolPicker(to canvas: PKCanvasView) {
            let picker = PKToolPicker()
            picker.setVisible(true, forFirstResponder: canvas)
            picker.addObserver(canvas)
            canvas.becomeFirstResponder()
            toolPicker = picker
        }

        func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
            isWriting = true
            parent.onBeginWriting()
        }

        func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
            isWriting = false
            // Le dessin est remonte ici plutot qu'a chaque micro-changement :
            // une fois le trait termine, l'etat est stable.
            parent.drawing = canvasView.drawing
            parent.onEndWriting()
        }
    }
}
#endif
