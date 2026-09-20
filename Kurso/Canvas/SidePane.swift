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

    func makeUIView(context: Context) -> ReadingScroll {
        let scroll = ReadingScroll()
        scroll.delegate = context.coordinator
        scroll.backgroundColor = UIColor(Color(token: DesignTokens.Palette.paperAlt))
        scroll.showsVerticalScrollIndicator = false
        scroll.showsHorizontalScrollIndicator = false
        scroll.contentInsetAdjustmentBehavior = .never
        scroll.page.image = image
        context.coordinator.scroll = scroll

        // Double tape pour zoomer, comme dans n'importe quel lecteur : on vise
        // un mot et on y est, sans pincer a deux doigts sur un iPad qu'on
        // tient deja d'une main.
        let twice = UITapGestureRecognizer(target: context.coordinator,
                                           action: #selector(Coordinator.zoomTwice))
        twice.numberOfTapsRequired = 2
        scroll.addGestureRecognizer(twice)
        return scroll
    }

    func updateUIView(_ scroll: ReadingScroll, context: Context) {
        guard scroll.page.image !== image else { return }
        scroll.page.image = image
        scroll.needsFraming = true
        scroll.setNeedsLayout()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var scroll: ReadingScroll?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            (scrollView as? ReadingScroll)?.page
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            (scrollView as? ReadingScroll)?.centre()
        }

        @objc func zoomTwice(_ gesture: UITapGestureRecognizer) {
            guard let scroll else { return }
            let fit = scroll.fitWidth
            // Deja agrandie : on revient a la pleine largeur, la taille ou
            // l'on lit. Pour voir la page entiere, on pince — le minimum
            // descend jusque-la.
            if scroll.zoomScale > fit + 0.01 {
                scroll.setZoomScale(fit, animated: true)
                return
            }
            let target = fit * 3
            let point = gesture.location(in: scroll.page)
            let size = CGSize(width: scroll.bounds.width / target,
                              height: scroll.bounds.height / target)
            scroll.zoom(to: CGRect(x: point.x - size.width / 2,
                                   y: point.y - size.height / 2,
                                   width: size.width, height: size.height),
                        animated: true)
        }
    }
}

/// Le defilement d'une page qu'on lit.
///
/// La mise en place se fait dans `layoutSubviews`, jamais dans la mise a jour
/// de la vue SwiftUI : celle-ci passe souvent AVANT que la vue ait sa taille
/// definitive, et le cadre restait alors celui d'une largeur nulle. La page
/// paraissait zoomee sans qu'on puisse y faire quoi que ce soit.
final class ReadingScroll: UIScrollView {
    let page = UIImageView()
    /// Une nouvelle image : on recadre a la pleine largeur.
    var needsFraming = true

    override init(frame: CGRect) {
        super.init(frame: frame)
        page.contentMode = .scaleAspectFit
        page.isUserInteractionEnabled = true
        addSubview(page)
    }

    required init?(coder: NSCoder) { fatalError("jamais depuis un storyboard") }

    /// L'echelle a laquelle la page occupe toute la largeur : celle ou l'on
    /// lit un enonce.
    var fitWidth: CGFloat {
        guard let size = page.image?.size, size.width > 0, bounds.width > 0 else { return 1 }
        return bounds.width / size.width
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let size = page.image?.size, size.width > 0, size.height > 0,
              bounds.width > 0, bounds.height > 0 else { return }

        // On peut dezoomer jusqu'a voir la page ENTIERE, et zoomer jusqu'a six
        // fois la taille de lecture. Ces bornes dependent du cadre, donc elles
        // se recalculent a chaque mise en page.
        let whole = min(bounds.width / size.width, bounds.height / size.height)
        minimumZoomScale = whole
        maximumZoomScale = max(fitWidth, whole) * 6

        if needsFraming {
            // La TAILLE de la page ne se pose qu'une fois, a l'arrivee d'une
            // nouvelle image.
            needsFraming = false
            page.transform = .identity
            page.frame = CGRect(origin: .zero, size: size)
            contentSize = size
            setZoomScale(fitWidth, animated: false)
        } else if zoomScale < minimumZoomScale || zoomScale > maximumZoomScale {
            setZoomScale(min(max(zoomScale, minimumZoomScale), maximumZoomScale), animated: false)
        }
        // SURTOUT NE PAS reposer `page.frame` ici. Un UIScrollView zoome en
        // TRANSFORMANT la vue qu'il agrandit : son cadre change donc a chaque
        // pincement. Le comparer a la taille de la page et le reaffecter
        // annulait le zoom dans la foulee — plus rien ne bougeait.
        centre()
    }

    /// Une page plus petite que le cadre se pose au milieu, pas en haut a
    /// gauche.
    ///
    /// `contentSize` porte DEJA la taille zoomee — le multiplier par l'echelle
    /// la comptait deux fois, et la page fuyait hors du cadre en zoomant.
    func centre() {
        let extraX = max(0, (bounds.width - contentSize.width) / 2)
        let extraY = max(0, (bounds.height - contentSize.height) / 2)
        let wanted = UIEdgeInsets(top: extraY, left: extraX, bottom: extraY, right: extraX)
        // Reaffecter une marge identique relance une mise en page : on evite
        // la boucle.
        if contentInset != wanted { contentInset = wanted }
    }
}
#endif
