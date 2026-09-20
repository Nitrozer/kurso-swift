#if os(iOS)
import SwiftUI
import UIKit
import KursoCore
import KursoModels

/// Le volet de consultation : une autre page, a cote de celle qu'on ecrit.
///
/// On lit a droite, on redige a gauche. C'est le geste du TD — l'enonce d'un
/// cote, la reponse de l'autre — et il valait mieux que des allers-retours
/// entre deux pages, qui sont exactement le moment ou l'on perd le fil.
///
/// **On y lit, on n'y ecrit pas.** Sur un iPad de onze pouces, deux canevas
/// cote a cote donneraient deux colonnes de quatre cents points : trop etroit
/// pour ecrire au stylet, dans l'une comme dans l'autre. Le volet se
/// redimensionne, donc on l'ouvre large pour lire et on le reduit pour
/// rediger — ce qui rend la place a l'ecriture, qui en a le plus besoin.
struct SidePane: View {
    let page: Page
    @Binding var width: CGFloat
    /// La largeur disponible pour le canevas ET le volet. Les bornes en
    /// dependent : un volet de six cents points est la moitie d'un ecran et
    /// le tiers d'un autre.
    let available: CGFloat
    var onChoose: () -> Void
    var onClose: () -> Void

    @State private var rendered: UIImage?
    @State private var dragStart: CGFloat?

    /// En dessous, on ne lit plus rien.
    static let minimum: CGFloat = 280

    /// Jusqu'aux trois quarts de la place : lire un enonce demande parfois
    /// presque tout l'ecran, et on reduit d'un geste pour rediger.
    static func maximum(in available: CGFloat) -> CGFloat {
        max(minimum, available * 0.75)
    }

    /// La moitie, a la premiere ouverture. C'est ce qu'on attend d'un volet
    /// qu'on met « a cote » : deux moities, pas une bande.
    static func suggested(in available: CGFloat) -> CGFloat {
        min(max(available * 0.5, minimum), maximum(in: available))
    }

    var body: some View {
        HStack(spacing: 0) {
            handle
            VStack(spacing: 0) {
                header
                if let rendered {
                    ZoomablePage(image: rendered)
                } else {
                    Color.clear
                }
            }
            .frame(width: min(max(width, SidePane.minimum), SidePane.maximum(in: available)))
            .background(K.paperAlt)
        }
        .task(id: PageThumbnails.signature(page)) {
            rendered = PageExporter.image(page, width: DrawingCanvas.pageWidth, density: 1)
        }
    }

    /// La poignee de largeur, au bord gauche du volet.
    private var handle: some View {
        Rectangle()
            .fill(K.ink.opacity(0.12))
            .frame(width: 1)
            .overlay {
                Capsule()
                    .fill(K.ink.opacity(0.18))
                    .frame(width: 4, height: 44)
            }
            // La zone sensible est bien plus large que le trait : un separateur
            // d'un point ne s'attrape pas au doigt.
            .contentShape(Rectangle().inset(by: -9))
            .gesture(
                DragGesture()
                    .onChanged { move in
                        let start = dragStart ?? width
                        dragStart = start
                        width = min(max(start - move.translation.width,
                                        SidePane.minimum),
                                    SidePane.maximum(in: available))
                    }
                    .onEnded { _ in dragStart = nil }
            )
    }

    private var header: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(page.title.isEmpty ? "Sans titre" : page.title)
                    .font(KFont.body(12.5, weight: .extraBold))
                    .foregroundStyle(K.ink)
                    .lineLimit(1)
                Text(page.course?.name.uppercased() ?? "SANS MATIÈRE")
                    .font(KFont.mono(9))
                    .tracking(0.8)
                    .foregroundStyle(K.inkSoft)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Button("Changer", action: onChoose)
                .buttonStyle(.plain)
                .font(KFont.body(10.5, weight: .extraBold))
                .foregroundStyle(K.brand)
            Button(action: onClose) {
                CrossGlyph()
                    .stroke(K.ink, style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                    .frame(width: 11, height: 11)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Fermer le volet")
        }
        .padding(.leading, 14)
        .padding(.trailing, 6)
        .frame(height: 46)
        .background(K.paper)
        .overlay(alignment: .bottom) {
            Rectangle().fill(K.ink.opacity(0.12)).frame(height: 1)
        }
    }
}

/// La page a lire : on la fait defiler et on zoome dedans.
///
/// Un `UIScrollView` plutot qu'un assemblage SwiftUI : le pincement, l'inertie
/// et les rebonds sont exactement ce qu'on attend en lisant un enonce, et
/// UIKit les donne sans qu'on les reecrive.
private struct ZoomablePage: UIViewRepresentable {
    let image: UIImage

    func makeUIView(context: Context) -> UIScrollView {
        let scroll = UIScrollView()
        scroll.delegate = context.coordinator
        // Six plutot que quatre : dans un volet etroit, le texte d'un enonce
        // scanne demande d'aller chercher loin.
        scroll.maximumZoomScale = 6
        scroll.minimumZoomScale = 1
        scroll.backgroundColor = UIColor(Color(token: DesignTokens.Palette.paperAlt))
        scroll.showsVerticalScrollIndicator = false
        scroll.showsHorizontalScrollIndicator = false
        scroll.contentInsetAdjustmentBehavior = .never

        let view = UIImageView(image: image)
        view.contentMode = .scaleAspectFit
        view.isUserInteractionEnabled = true
        scroll.addSubview(view)
        context.coordinator.page = view
        context.coordinator.scroll = scroll

        // Double tape pour zoomer, comme dans n'importe quel lecteur : on
        // vise un mot et on y est, sans pincer a deux doigts sur un iPad
        // qu'on tient deja d'une main.
        let twice = UITapGestureRecognizer(target: context.coordinator,
                                           action: #selector(Coordinator.zoomTwice))
        twice.numberOfTapsRequired = 2
        scroll.addGestureRecognizer(twice)
        return scroll
    }

    func updateUIView(_ scroll: UIScrollView, context: Context) {
        guard let view = context.coordinator.page else { return }
        if view.image !== image {
            view.image = image
            scroll.setZoomScale(1, animated: false)
        }
        // A pleine largeur, la hauteur suit le rapport de la page.
        let width = scroll.bounds.width
        guard width > 0, image.size.width > 0 else { return }
        let height = width * image.size.height / image.size.width
        view.frame = CGRect(x: 0, y: 0, width: width, height: height)
        scroll.contentSize = CGSize(width: width, height: height)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        var page: UIImageView?
        weak var scroll: UIScrollView?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? { page }

        @objc func zoomTwice(_ gesture: UITapGestureRecognizer) {
            guard let scroll else { return }
            if scroll.zoomScale > scroll.minimumZoomScale + 0.01 {
                scroll.setZoomScale(scroll.minimumZoomScale, animated: true)
                return
            }
            // On zoome SUR le point touche, pas au centre : c'est le mot
            // qu'on vise qu'on veut voir grossir.
            let target: CGFloat = 3
            let point = gesture.location(in: page)
            let size = CGSize(width: scroll.bounds.width / target,
                              height: scroll.bounds.height / target)
            scroll.zoom(to: CGRect(x: point.x - size.width / 2,
                                   y: point.y - size.height / 2,
                                   width: size.width, height: size.height),
                        animated: true)
        }
    }
}
#endif
