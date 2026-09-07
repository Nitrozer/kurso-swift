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

    /// Le trace tel qu'il est A CET INSTANT.
    ///
    /// Enregistrer depuis l'etat SwiftUI perdait le dernier trait : l'etat est
    /// propage de facon asynchrone, et quitter la page n'attend pas.
    var currentDrawing: PKDrawing? { canvas?.drawing }

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
    /// Format d'une page, en points. Proche d'un A4 a l'echelle de l'ecran.
    static let pageWidth: CGFloat = 1_240
    static let pageHeight: CGFloat = 3_000

    @Binding var drawing: PKDrawing
    var handle: CanvasHandle?
    /// Modele de page affiche sous l'ecriture.
    var template: PaperView.Template = .ruled
    /// Le stylet touche la surface.
    var onBeginWriting: () -> Void
    /// Le stylet quitte la surface : c'est aussi le moment ou l'on enregistre.
    ///
    /// Le trace est passe en argument, jamais relu depuis l'etat : SwiftUI
    /// propage un @Binding de facon asynchrone, donc enregistrer juste apres
    /// l'avoir ecrit sauvegardait souvent la version precedente. C'est ce qui
    /// faisait disparaitre des traits une fois sur deux.
    var onEndWriting: (PKDrawing) -> Void

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
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

        // PKCanvasView est un UIScrollView : le pincement zoome, comme dans
        // n'importe quelle app de prise de notes.
        canvas.minimumZoomScale = 1
        canvas.maximumZoomScale = 5
        canvas.bouncesZoom = true
        // Une page haute, pour pouvoir ecrire au-dela de l'ecran.
        canvas.contentSize = CGSize(width: DrawingCanvas.pageWidth, height: DrawingCanvas.pageHeight)

        // Le papier vit dans le contenu du canevas, sous les traits : il defile
        // et zoome avec l'ecriture.
        let paper = PaperView(frame: CGRect(origin: .zero, size: canvas.contentSize))
        paper.template = template
        canvas.insertSubview(paper, at: 0)
        context.coordinator.paper = paper

        context.coordinator.attachToolPicker(to: canvas)
        handle?.canvas = canvas
        // En dernier : brancher le delegue avant d'avoir pose le trace initial
        // faisait passer ce trace pour une modification de l'utilisateur.
        canvas.delegate = context.coordinator
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        context.coordinator.paper?.template = template
        // Le papier suit la taille du contenu, pas celle de la vue : zoomer
        // agrandit la page, il ne doit pas rester au format d'origine.
        context.coordinator.paper?.frame = CGRect(origin: .zero, size: canvas.contentSize)

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
        var paper: PaperView?
        private(set) var isWriting = false

        init(_ parent: DrawingCanvas) { self.parent = parent }

        func attachToolPicker(to canvas: PKCanvasView) {
            let picker = PKToolPicker()
            picker.setVisible(true, forFirstResponder: canvas)
            picker.addObserver(canvas)
            canvas.becomeFirstResponder()
            toolPicker = picker
        }

        /// Le papier n'est pas la vue que PKCanvasView met a l'echelle : il faut
        /// le redimensionner nous-memes a chaque zoom, sinon les lignes restent
        /// a leur taille d'origine pendant que l'ecriture grandit.
        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            paper?.frame = CGRect(origin: .zero, size: scrollView.contentSize)
        }

        func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
            isWriting = true
            parent.onBeginWriting()
        }

        func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
            isWriting = false
            commit(canvasView)
        }

        /// Filet de securite : certains changements n'emettent pas de fin
        /// d'outil — une gomme, un collage, une annulation. Sans ce rappel, ils
        /// n'etaient jamais enregistres.
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            guard !isWriting else { return }
            // PencilKit signale aussi nos propres affectations. Si le canevas
            // dit deja la meme chose que le modele, il n'y a rien de nouveau —
            // et surtout rien a ecrire par-dessus la page.
            guard canvasView.drawing != parent.drawing else { return }
            commit(canvasView)
        }

        private func commit(_ canvasView: PKCanvasView) {
            let snapshot = canvasView.drawing
            parent.drawing = snapshot
            parent.onEndWriting(snapshot)
        }
    }
}
#endif
