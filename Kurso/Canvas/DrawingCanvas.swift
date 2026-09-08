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

/// Un canevas qui previent quand il se dispose.
///
/// Le fond doit etre recale a chaque mise en page : sans ce signal, il gardait
/// la taille qu'il avait avant le premier layout — c'est-a-dire aucune — et
/// n'etait jamais dessine tant qu'on n'avait pas zoome ou fait defiler.
final class PaperBackedCanvas: PKCanvasView {
    var onLayout: (() -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        onLayout?()
    }
}

struct DrawingCanvas: UIViewRepresentable {
    /// Format d'une page, en points. Proche d'un A4 a l'echelle de l'ecran.
    static let pageWidth: CGFloat = 1_240
    static let pageHeight: CGFloat = 3_000

    @Binding var drawing: PKDrawing
    var handle: CanvasHandle?
    /// Signale l'etat du canevas : c'est le fond, derriere, qui s'y accorde.
    var onViewportChange: (PaperBackdrop.Viewport) -> Void = { _ in }
    /// Le stylet touche la surface.
    var onBeginWriting: () -> Void
    /// Le stylet quitte la surface : c'est aussi le moment ou l'on enregistre.
    ///
    /// Le trace est passe en argument, jamais relu depuis l'etat : SwiftUI
    /// propage un @Binding de facon asynchrone, donc enregistrer juste apres
    /// l'avoir ecrit sauvegardait souvent la version precedente. C'est ce qui
    /// faisait disparaitre des traits une fois sur deux.
    var onEndWriting: (PKDrawing) -> Void

    func makeUIView(context: Context) -> PaperBackedCanvas {
        let canvas = PaperBackedCanvas()
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

        // Le fond est une vue soeur, derriere : il ne peut donc pas entrer en
        // conflit avec la mise en page du scroll view.
        canvas.onLayout = { [weak canvas, weak coordinator = context.coordinator] in
            guard let canvas, let coordinator else { return }
            coordinator.report(canvas)
        }

        context.coordinator.attachToolPicker(to: canvas)
        handle?.canvas = canvas
        // En dernier : brancher le delegue avant d'avoir pose le trace initial
        // faisait passer ce trace pour une modification de l'utilisateur.
        canvas.delegate = context.coordinator

        #if DEBUG
        if let i = ProcessInfo.processInfo.arguments.firstIndex(of: "-simulateZoom"),
           i + 1 < ProcessInfo.processInfo.arguments.count,
           let scale = Double(ProcessInfo.processInfo.arguments[i + 1]) {
            let coordinator = context.coordinator
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                canvas.setZoomScale(CGFloat(scale), animated: false)
                coordinator.report(canvas)
                print("[KURSO] zoom=\(canvas.zoomScale) contenu=\(canvas.contentSize)")
            }
        }

        // Reproduit un trait reel : debut d'outil, trace, fin d'outil. C'est
        // exactement le chemin qu'emprunte le stylet.
        if ProcessInfo.processInfo.arguments.contains("-simulateStroke") {
            let coordinator = context.coordinator
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                coordinator.canvasViewDidBeginUsingTool(canvas)
                var strokes = canvas.drawing.strokes
                strokes.append(Self.debugStroke(atY: 300 + CGFloat(strokes.count) * 60))
                canvas.drawing = PKDrawing(strokes: strokes)
                coordinator.canvasViewDidEndUsingTool(canvas)
                print("[KURSO] trait simule, total=\(canvas.drawing.strokes.count)")
            }
        }
        #endif

        return canvas
    }

    func updateUIView(_ canvas: PaperBackedCanvas, context: Context) {
        context.coordinator.report(canvas)

        // Ne reinjecter que si le modele a change ailleurs : reaffecter le dessin
        // pendant que l'utilisateur ecrit interromprait son trait.
        if canvas.drawing != drawing && !context.coordinator.isWriting {
            canvas.drawing = drawing
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    #if DEBUG
    /// Un trait droit, uniquement pour les essais automatises.
    static func debugStroke(atY y: CGFloat) -> PKStroke {
        let ink = PKInk(.pen, color: .black)
        let points = (0..<40).map { i in
            PKStrokePoint(location: CGPoint(x: 80 + Double(i) * 12, y: Double(y)),
                          timeOffset: Double(i) / 100, size: CGSize(width: 4, height: 4),
                          opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
        }
        return PKStroke(ink: ink, path: PKStrokePath(controlPoints: points, creationDate: Date()))
    }
    #endif

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        private let parent: DrawingCanvas
        private var toolPicker: PKToolPicker?
        private(set) var isWriting = false
        private var lastReported: PaperBackdrop.Viewport?

        init(_ parent: DrawingCanvas) { self.parent = parent }

        func attachToolPicker(to canvas: PKCanvasView) {
            let picker = PKToolPicker()
            picker.setVisible(true, forFirstResponder: canvas)
            picker.addObserver(canvas)
            canvas.becomeFirstResponder()
            toolPicker = picker
        }

        /// Le fond, derriere, se cale sur ces deux valeurs.
        func scrollViewDidZoom(_ scrollView: UIScrollView) { report(scrollView) }
        func scrollViewDidScroll(_ scrollView: UIScrollView) { report(scrollView) }

        func report(_ scrollView: UIScrollView) {
            let next = PaperBackdrop.Viewport(zoom: scrollView.zoomScale,
                                              offset: scrollView.contentOffset)
            guard next != lastReported else { return }
            lastReported = next
            parent.onViewportChange(next)
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
