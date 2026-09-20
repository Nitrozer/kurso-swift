#if os(iOS)
import SwiftUI
import UIKit
import KursoCore
import KursoModels

/// Manipulation des images posees, en UIKit.
///
/// PencilKit ne connait pas les images : aucun composant Apple ne fait « une
/// image redimensionnable sur un canevas de dessin ». En revanche UIKit sait
/// arbitrer les gestes — c'est ce qui manquait.
///
/// Cette couche ne DESSINE rien : les images sont peintes par le fond, sous
/// l'encre. Elle ne porte que les zones sensibles et la selection. Et son
/// `hitTest` ne retient que ce qui touche une image : tout le reste tombe au
/// canevas, donc le stylet ecrit et le pincement zoome comme avant.
struct PlacedImagesLayer: UIViewRepresentable {
    let items: [PageImage]
    let viewport: PaperBackdrop.Viewport
    @Binding var selected: UUID?
    var onChange: (PageImage, CGRect) -> Void
    var onDelete: (PageImage) -> Void

    func makeUIView(context: Context) -> PassthroughView {
        let view = PassthroughView()
        context.coordinator.host = view
        return view
    }

    func updateUIView(_ view: PassthroughView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.rebuild(in: view)
    }


    /// Prend toute la place qu'on lui propose.
    ///
    /// Sans cela, la mise en page donnait a cette couche une taille arbitraire
    /// — 281 points de large pour une page de 1 240 — et UIKit refusait tout
    /// toucher au-dela : les objets se voyaient mais restaient inatteignables.
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: PassthroughView,
                      context: Context) -> CGSize? {
        proposal.replacingUnspecifiedDimensions()
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    // MARK: Coordination

    @MainActor final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: PlacedImagesLayer
        weak var host: PassthroughView?
        private var handles: [UUID: HandleView] = [:]

        init(_ parent: PlacedImagesLayer) { self.parent = parent }

        func rebuild(in view: PassthroughView) {
            let wanted = Set(parent.items.map(\.id))
            for (id, handle) in handles where !wanted.contains(id) {
                handle.removeFromSuperview()
                handles[id] = nil
            }

            for item in parent.items {
                let handle = handles[item.id] ?? makeHandle(for: item, in: view)
                handle.item = item
                handle.frame = frame(for: item)
                handle.isSelected = (item.id == parent.selected)
            }
        }

        private func makeHandle(for item: PageImage, in view: PassthroughView) -> HandleView {
            let handle = HandleView()
            handle.onTap = { [weak self] in
                guard let self else { return }
                parent.selected = (parent.selected == item.id) ? nil : item.id
            }
            handle.onDelete = { [weak self] in
                guard let self, let current = handle.item else { return }
                parent.selected = nil
                parent.onDelete(current)
            }
            handle.onCommit = { [weak self] rect in
                guard let self, let current = handle.item,
                      let box = ImagePlacement.box(from: rect, in: self.pageRect) else { return }
                parent.onChange(current, box)
            }
            // Deplacer et retailler cohabitent : UIKit sait les melanger,
            // c'est tout l'interet de passer par lui.
            handle.pan.delegate = self
            handle.pinch.delegate = self
            view.addSubview(handle)
            handles[item.id] = handle
            return handle
        }

        nonisolated func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool { true }

        private var pageRect: CGRect {
            CGRect(x: -parent.viewport.offset.x, y: -parent.viewport.offset.y,
                   width: PaperBackdrop.pageWidth * parent.viewport.zoom,
                   height: PaperBackdrop.pageHeight * parent.viewport.zoom)
        }

        private func frame(for item: PageImage) -> CGRect {
            let page = pageRect
            return CGRect(x: page.minX + item.x * page.width,
                          y: page.minY + item.y * page.height,
                          width: item.width * page.width,
                          height: item.height * page.height)
        }
    }
}

/// Une vue qui ne retient que ce qui touche ses enfants.
///
/// Elle interroge ses enfants elle-meme, sans passer par `super`. Et c'est
/// tout l'interet : UIKit ne teste JAMAIS le toucher hors des limites d'une
/// vue, alors que le dessin, lui, deborde sans rien dire. Cette couche recoit
/// de la mise en page une taille bien plus petite que la page, et ses enfants
/// tombaient donc en dehors : on les voyait, aucun doigt ne les atteignait.
/// Les images posees comme les blocs de texte etaient immobiles pour cette
/// seule raison.
final class PassthroughView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard isUserInteractionEnabled, !isHidden, alpha > 0.01 else { return nil }
        // Du dernier pose au premier : celui du dessus repond en premier.
        for child in subviews.reversed() {
            guard !child.isHidden, child.isUserInteractionEnabled, child.alpha > 0.01 else { continue }
            if let hit = child.hitTest(convert(point, to: child), with: event) { return hit }
        }
        // Rien a nous sous ce point : le canevas le recoit.
        return nil
    }
}

/// La zone sensible d'une image : invisible, sauf quand elle est choisie.
final class HandleView: UIView {
    var item: PageImage?
    var onTap: (() -> Void)?
    var onDelete: (() -> Void)?
    var onCommit: ((CGRect) -> Void)?

    let pan = UIPanGestureRecognizer()
    let pinch = UIPinchGestureRecognizer()
    private let deleteButton = UIButton(type: .system)
    private var start: CGRect = .zero

    var isSelected = false {
        didSet {
            layer.borderWidth = isSelected ? 2.5 : 0
            deleteButton.isHidden = !isSelected
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        layer.borderColor = UIColor(red: 0.23, green: 0.36, blue: 1, alpha: 1).cgColor
        layer.cornerRadius = 4

        pan.addTarget(self, action: #selector(handlePan))
        pinch.addTarget(self, action: #selector(handlePinch))
        addGestureRecognizer(pan)
        addGestureRecognizer(pinch)
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))

        deleteButton.setTitle("✕", for: .normal)
        deleteButton.tintColor = .white
        deleteButton.backgroundColor = UIColor(red: 0.07, green: 0.10, blue: 0.20, alpha: 1)
        deleteButton.layer.cornerRadius = 13
        deleteButton.isHidden = true
        deleteButton.addTarget(self, action: #selector(handleDelete), for: .touchUpInside)
        addSubview(deleteButton)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        deleteButton.frame = CGRect(x: -13, y: -13, width: 26, height: 26)
    }

    /// La croix deborde du cadre : sans ca elle n'est pas touchable.
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        if !deleteButton.isHidden, deleteButton.frame.insetBy(dx: -6, dy: -6).contains(point) {
            return true
        }
        return bounds.contains(point)
    }

    @objc private func handleTap() { onTap?() }
    @objc private func handleDelete() { onDelete?() }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let parent = superview else { return }
        switch gesture.state {
        case .began:
            start = frame
        case .changed:
            let move = gesture.translation(in: parent)
            frame = start.offsetBy(dx: move.x, dy: move.y)
        case .ended, .cancelled:
            onCommit?(frame)
        default:
            break
        }
    }

    /// Le pincement retaille SANS deformer : une image etiree ne ressemble
    /// a rien, et ce n'est jamais ce qu'on veut.
    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        switch gesture.state {
        case .began:
            start = frame
        case .changed:
            let scale = max(0.2, min(6, gesture.scale))
            let width = max(60, start.width * scale)
            let height = width * (start.height / max(start.width, 1))
            frame = CGRect(x: start.midX - width / 2, y: start.midY - height / 2,
                           width: width, height: height)
        case .ended, .cancelled:
            onCommit?(frame)
        default:
            break
        }
    }
}
#endif
