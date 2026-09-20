#if os(iOS)
import SwiftUI
import UIKit
import KursoCore
import KursoModels

/// Les blocs de texte tapes au clavier, poses par-dessus le canevas.
///
/// Meme principe que les images : la couche est transparente et ne retient que
/// ce qui touche un bloc, tout le reste descend au canevas. Ce qui change,
/// c'est le zoom — un bloc porte sa taille en coordonnees de PAGE et recoit le
/// zoom par une transformation. Sans cela, le texte garderait la meme taille a
/// l'ecran pendant que la page grandit sous lui.
struct TextBlocksLayer: UIViewRepresentable {
    let items: [PageText]
    let viewport: PaperBackdrop.Viewport
    /// Le bloc qui vient d'etre cree et doit recevoir le clavier.
    var focusRequest: UUID?
    var onMove: (PageText, CGRect) -> Void
    var onEdit: (PageText, Data?, String, CGFloat) -> Void
    var onDelete: (PageText) -> Void
    /// On a quitte un bloc : la palette d'ecriture peut revenir.
    var onDoneEditing: () -> Void = {}

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

    @MainActor final class Coordinator: NSObject {
        var parent: TextBlocksLayer
        weak var host: PassthroughView?
        private var blocks: [UUID: TextBlockView] = [:]
        /// Le bloc deja mis au clavier : on ne le refait pas a chaque passage.
        private var focused: UUID?

        init(_ parent: TextBlocksLayer) { self.parent = parent }

        func rebuild(in view: PassthroughView) {
            let wanted = Set(parent.items.map(\.id))
            for (id, block) in blocks where !wanted.contains(id) {
                block.removeFromSuperview()
                blocks[id] = nil
            }

            for item in parent.items {
                let block = blocks[item.id] ?? make(item, in: view)
                block.item = item
                block.load(item)
                // Filet de securite : un glissement coupe par accident ne doit
                // pas condamner le bloc a ne plus jamais bouger.
                block.pan.isEnabled = true
                place(block, for: item)
            }

            if let wantsFocus = parent.focusRequest, wantsFocus != focused,
               let block = blocks[wantsFocus] {
                focused = wantsFocus
                block.beginEditing()
            }
            if parent.focusRequest == nil { focused = nil }
        }

        private func make(_ item: PageText, in view: PassthroughView) -> TextBlockView {
            let block = TextBlockView()
            block.onMoved = { [weak self, weak block] translation in
                guard let self, let block, let current = block.item else { return }
                let page = pageRect
                guard page.width > 0, page.height > 0 else { return }
                var box = current.rect
                box.origin.x += translation.x / page.width
                box.origin.y += translation.y / page.height
                // Un bloc a moitie dehors ne se rattrape plus.
                box.origin.x = min(max(box.origin.x, 0), max(0, 1 - box.width))
                box.origin.y = min(max(box.origin.y, 0), max(0, 1 - box.height))
                parent.onMove(current, box)
            }
            block.onEdited = { [weak self, weak block] attributed, fittedHeight in
                guard let self, let block, let current = block.item else { return }
                let rtf = try? attributed.data(
                    from: NSRange(location: 0, length: attributed.length),
                    documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
                parent.onEdit(current, rtf, attributed.string,
                              fittedHeight / DrawingCanvas.pageHeight)
            }
            block.onEmptied = { [weak self, weak block] in
                guard let self, let block, let current = block.item else { return }
                // Un bloc vide qu'on quitte n'a aucune raison de rester : il
                // ne se voit pas, et il se redecouvre au hasard d'un doigt.
                parent.onDelete(current)
            }
            block.onDoneEditing = { [weak self] in self?.parent.onDoneEditing() }
            view.addSubview(block)
            blocks[item.id] = block
            return block
        }

        private var pageRect: CGRect {
            CGRect(x: -parent.viewport.offset.x, y: -parent.viewport.offset.y,
                   width: DrawingCanvas.pageWidth * parent.viewport.zoom,
                   height: DrawingCanvas.pageHeight * parent.viewport.zoom)
        }

        /// Pose le bloc : taille en coordonnees de page, zoom par
        /// transformation. C'est ce qui fait grandir le texte avec la page.
        private func place(_ block: TextBlockView, for item: PageText) {
            guard !block.isBeingMoved else { return }
            let page = pageRect
            let zoom = max(parent.viewport.zoom, 0.01)
            let unscaled = CGSize(width: item.width * DrawingCanvas.pageWidth,
                                  height: max(item.height * DrawingCanvas.pageHeight, 36))
            block.transform = .identity
            block.bounds = CGRect(origin: .zero, size: unscaled)
            block.transform = CGAffineTransform(scaleX: zoom, y: zoom)
            block.center = CGPoint(x: page.minX + (item.x + item.width / 2) * page.width,
                                   y: page.minY + (item.y + item.height / 2) * page.height)
            block.fit()
        }
    }
}

/// Un bloc de texte : la zone de saisie, et rien autour tant qu'on n'y touche
/// pas.
final class TextBlockView: UIView, UITextViewDelegate {
    let textView = UITextView()
    var item: PageText?
    var onMoved: ((CGPoint) -> Void)?
    var onEdited: ((NSAttributedString, CGFloat) -> Void)?
    var onEmptied: (() -> Void)?
    var onDoneEditing: (() -> Void)?
    let pan = UIPanGestureRecognizer()
    private(set) var isBeingMoved = false
    private var loadedID: UUID?


    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear

        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        // AU REPOS, LE BLOC EST UN OBJET.
        //
        // Une zone de saisie active porte ses propres gestes — loupe,
        // selection, appui long — et ils passaient AVANT le notre : le bloc
        // ne se deplacait jamais. Elle ne s'active qu'une fois qu'on a tape
        // dedans, et se rendort quand on en sort.
        textView.isEditable = false
        textView.isSelectable = false
        // La mise en forme du systeme : gras, italique, souligne, au clavier
        // comme au menu. On ne reconstruit pas une barre d'outils pour ca.
        textView.allowsEditingTextAttributes = true
        textView.textContainerInset = UIEdgeInsets(top: 6, left: 4, bottom: 6, right: 4)
        textView.textContainer.lineFragmentPadding = 0
        textView.font = TextBlockView.bodyFont
        textView.textColor = UIColor(Color(token: DesignTokens.Palette.ink))
        textView.tintColor = UIColor(Color(token: DesignTokens.Palette.brand))
        textView.delegate = self
        addSubview(textView)

        // Un cadre a peine visible : un objet qu'on peut saisir doit se voir,
        // sinon on ne sait pas qu'il est la ni qu'il se deplace.
        layer.cornerRadius = 10
        layer.borderWidth = 1.5
        layer.borderColor = UIColor(Color(token: DesignTokens.Palette.ink)).withAlphaComponent(0.12).cgColor

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)

        // Un simple glissement deplace le bloc, comme une image posee. Pas
        // d'appui long : un geste qu'il faut deviner n'existe pas, et rien a
        // l'ecran ne pouvait l'enseigner.
        //
        // Aucun conflit avec la tape : l'une demande du mouvement, l'autre
        // exige l'immobilite.
        //
        // Et il reste actif MEME PENDANT LA SAISIE. Le couper le temps d'ecrire
        // paraissait poli ; en pratique il ne se rallumait qu'a la fin de la
        // saisie, et une zone de texte ne rend pas toujours le clavier quand on
        // touche ailleurs. Le bloc devenait alors immobile pour de bon.
        pan.addTarget(self, action: #selector(handlePan))
        addGestureRecognizer(pan)
    }

    required init?(coder: NSCoder) { fatalError("jamais depuis un storyboard") }

    /// Passe en saisie, curseur au plus pres de l'endroit touche.
    func beginEditing(at point: CGPoint? = nil) {
        textView.isEditable = true
        textView.isSelectable = true
        textView.becomeFirstResponder()
        if let point,
           let position = textView.closestPosition(to: point),
           let range = textView.textRange(from: position, to: position) {
            textView.selectedTextRange = range
        }
        setEditingLook(true)
    }

    private func setEditingLook(_ editing: Bool) {
        let ink = UIColor(Color(token: DesignTokens.Palette.ink))
        let brand = UIColor(Color(token: DesignTokens.Palette.brand))
        layer.borderColor = editing
            ? brand.withAlphaComponent(0.55).cgColor
            : ink.withAlphaComponent(0.12).cgColor
        layer.borderWidth = editing ? 2 : 1.5
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard !textView.isEditable else { return }
        beginEditing(at: gesture.location(in: textView))
    }

    static let bodyFont: UIFont = {
        UIFont(name: "Nunito-SemiBold", size: 17) ?? .systemFont(ofSize: 17, weight: .medium)
    }()

    override func layoutSubviews() {
        super.layoutSubviews()
        textView.frame = bounds
    }

    /// Recharge depuis le modele, une seule fois par bloc : le refaire a
    /// chaque passage replacerait le curseur au debut a chaque frappe.
    func load(_ item: PageText) {
        guard loadedID != item.id else { return }
        loadedID = item.id
        if let rtf = item.rtf,
           let attributed = try? NSAttributedString(
                data: rtf,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil) {
            textView.attributedText = attributed
        } else {
            textView.text = item.plain
        }
        textView.font = TextBlockView.bodyFont
        textView.textColor = UIColor(Color(token: DesignTokens.Palette.ink))
    }

    /// La hauteur suit le texte : un bloc grandit, il ne se retaille pas.
    @discardableResult
    func fit() -> CGFloat {
        let fitted = textView.sizeThatFits(CGSize(width: bounds.width,
                                                  height: .greatestFiniteMagnitude)).height
        let height = max(fitted, 36)
        if abs(bounds.height - height) > 0.5 {
            let keep = transform
            transform = .identity
            bounds = CGRect(x: 0, y: 0, width: bounds.width, height: height)
            transform = keep
        }
        return height
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let host = superview else { return }
        switch gesture.state {
        case .began:
            isBeingMoved = true
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            UIView.animate(withDuration: 0.12) {
                self.alpha = 0.9
                self.layer.shadowOpacity = 0.18
                self.layer.shadowRadius = 8
                self.layer.shadowOffset = CGSize(width: 0, height: 4)
            }
        case .changed:
            let translation = gesture.translation(in: host)
            gesture.setTranslation(.zero, in: host)
            center = CGPoint(x: center.x + translation.x, y: center.y + translation.y)
            onMoved?(translation)
        case .ended, .cancelled, .failed:
            isBeingMoved = false
            UIView.animate(withDuration: 0.12) {
                self.alpha = 1
                self.layer.shadowOpacity = 0
            }
        default:
            break
        }
    }

    // MARK: Saisie

    func textViewDidChange(_ textView: UITextView) {
        let height = fit()
        onEdited?(textView.attributedText, height)
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        // On se rendort : sinon le bloc reste insaisissable pour toujours.
        textView.isEditable = false
        textView.isSelectable = false
        setEditingLook(false)
        let trimmed = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        // PAS pendant un deplacement. L'appui long rend le clavier, ce qui
        // termine la saisie : un bloc encore vide s'effacait donc a l'instant
        // meme ou on essayait de l'attraper. On le garde — il porte un cadre,
        // on le retrouve, et on le remplit apres l'avoir pose.
        if trimmed.isEmpty, !isBeingMoved {
            onEmptied?()
        } else if !trimmed.isEmpty {
            onEdited?(textView.attributedText, fit())
            onDoneEditing?()
        }
    }
}
#endif
