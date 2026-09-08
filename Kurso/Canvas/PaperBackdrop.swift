import SwiftUI

/// Le fond de la page : papier reglé, ou la diapo d'un PDF.
///
/// Il vit DERRIERE le canevas, pas dedans. Une sous-vue de PKCanvasView ne
/// suit pas le zoom — la recaler a la main revenait soit a demander un calque
/// d'un gigaoctet a 5x, soit a se battre avec la mise en page du scroll view.
///
/// Ici, le fond fait toujours la taille de l'ecran et se contente de redessiner
/// ses lignes a l'echelle courante. Il reste net a n'importe quel zoom parce
/// qu'il est retrace, jamais agrandi.
struct PaperBackdrop: View {
    struct Viewport: Equatable {
        var zoom: CGFloat = 1
        var offset: CGPoint = .zero
        var size: CGSize = .zero
    }

    /// Un morceau de diapo rendu a la resolution de l'ecran.
    /// `crop` est normalise dans l'image de base, origine en haut a gauche.
    struct Tile {
        var image: CGImage
        var crop: CGRect
    }

    var viewport: Viewport
    var template: PaperTemplate
    var pageSize: CGSize
    var pdfImage: CGImage?
    /// La zone visible, rendue plus finement. L'image de base reste dessous :
    /// une tuile en retard laisse voir une diapo floue, jamais un trou.
    var pdfTile: Tile?

    private let lineSpacing: CGFloat = 32
    private let marginX: CGFloat = 96

    private let desk = Color(red: 0.878, green: 0.894, blue: 0.949)
    private let paper = Color(red: 0.980, green: 0.984, blue: 1.0)
    private let rule = Color(red: 0.847, green: 0.867, blue: 0.937)
    private let margin = Color(red: 1.0, green: 0.612, blue: 0.639).opacity(0.55)

    var body: some View {
        Canvas(opaque: true, rendersAsynchronously: false) { context, size in
            let bounds = CGRect(origin: .zero, size: size)
            context.fill(Path(bounds), with: .color(desk))

            let page = CGRect(x: -viewport.offset.x, y: -viewport.offset.y,
                              width: pageSize.width * viewport.zoom,
                              height: pageSize.height * viewport.zoom)
            guard page.intersects(bounds) else { return }
            context.fill(Path(page), with: .color(paper))

            context.clip(to: Path(page.intersection(bounds)))

            if let pdfImage {
                let fitted = Self.fitted(CGSize(width: pdfImage.width, height: pdfImage.height),
                                         into: page)
                context.draw(Image(decorative: pdfImage, scale: 1), in: fitted)
                if let tile = pdfTile {
                    let target = CGRect(
                        x: fitted.minX + tile.crop.minX * fitted.width,
                        y: fitted.minY + tile.crop.minY * fitted.height,
                        width: tile.crop.width * fitted.width,
                        height: tile.crop.height * fitted.height
                    )
                    context.draw(Image(decorative: tile.image, scale: 1), in: target)
                }
                return
            }
            guard template != .blank else { return }

            let step = lineSpacing * viewport.zoom
            guard step > 4 else { return }   // trop serré pour vouloir dire quelque chose

            if template == .dotted {
                for y in ticks(from: page.minY, step: step, limit: page.maxY, visible: 0...size.height) {
                    for x in ticks(from: page.minX, step: step, limit: page.maxX, visible: 0...size.width) {
                        context.fill(Path(ellipseIn: CGRect(x: x - 1, y: y - 1, width: 2, height: 2)),
                                     with: .color(rule))
                    }
                }
                return
            }

            var lines = Path()
            for y in ticks(from: page.minY, step: step, limit: page.maxY, visible: 0...size.height) {
                lines.move(to: CGPoint(x: page.minX, y: y))
                lines.addLine(to: CGPoint(x: page.maxX, y: y))
            }
            if template == .grid {
                for x in ticks(from: page.minX, step: step, limit: page.maxX, visible: 0...size.width) {
                    lines.move(to: CGPoint(x: x, y: page.minY))
                    lines.addLine(to: CGPoint(x: x, y: page.maxY))
                }
            }
            context.stroke(lines, with: .color(rule), lineWidth: 1)

            if template == .ruled {
                let x = page.minX + marginX * viewport.zoom
                var m = Path()
                m.move(to: CGPoint(x: x, y: page.minY))
                m.addLine(to: CGPoint(x: x, y: page.maxY))
                context.stroke(m, with: .color(margin), lineWidth: 1.5)
            }
        }
    }

    /// Les graduations reellement visibles. A fort zoom la page fait des
    /// milliers de points : les parcourir toutes couterait le fil principal.
    private func ticks(from origin: CGFloat, step: CGFloat, limit: CGFloat,
                       visible: ClosedRange<CGFloat>) -> [CGFloat] {
        guard step > 0.5 else { return [] }
        let first = max(0, floor((visible.lowerBound - origin) / step))
        var out: [CGFloat] = []
        var v = origin + first * step
        while v <= min(limit, visible.upperBound) {
            if v >= visible.lowerBound { out.append(v) }
            v += step
        }
        return out
    }

    static func fitted(_ size: CGSize, into rect: CGRect) -> CGRect {
        guard size.width > 0, size.height > 0 else { return rect }
        let scale = min(rect.width / size.width, rect.height / size.height)
        let w = size.width * scale, h = size.height * scale
        return CGRect(x: rect.midX - w / 2, y: rect.minY, width: w, height: h)
    }
}

/// Modele de page. Vit hors de PaperView pour rester disponible sur Mac.
enum PaperTemplate: String, CaseIterable, Sendable {
    case blank, ruled, grid, dotted
}
