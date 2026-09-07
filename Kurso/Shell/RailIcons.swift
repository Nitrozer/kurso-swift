import SwiftUI

/// Les cinq icones du rail, tracees d'apres le prototype.
///
/// Dessinees, pas empruntees : « toutes les icones sont dessinees au meme trait,
/// un jeu generique annule tout le reste ». Chaque trace est exprime dans la
/// boite 24×24 du prototype, puis mis a l'echelle.
struct RailIcon: Shape {
    enum Kind { case day, notebooks, memory, review, cards }
    var kind: Kind

    func path(in rect: CGRect) -> Path {
        let u = min(rect.width, rect.height) / 24
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * u, y: rect.minY + y * u)
        }
        func circle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) -> Path {
            Path(ellipseIn: CGRect(x: rect.minX + (cx - r) * u, y: rect.minY + (cy - r) * u,
                                   width: r * 2 * u, height: r * 2 * u))
        }
        func line(_ path: inout Path, _ a: (CGFloat, CGFloat), _ b: (CGFloat, CGFloat)) {
            path.move(to: p(a.0, a.1)); path.addLine(to: p(b.0, b.1))
        }

        var path = Path()
        switch kind {
        case .day:
            path.addPath(circle(12, 12, 4.2))
            let rays: [((CGFloat, CGFloat), (CGFloat, CGFloat))] = [
                ((12, 2.2), (12, 4.6)),     ((12, 19.4), (12, 21.8)),
                ((4.1, 4.1), (5.8, 5.8)),   ((18.2, 18.2), (19.9, 19.9)),
                ((2.2, 12), (4.6, 12)),     ((19.4, 12), (21.8, 12)),
                ((4.1, 19.9), (5.8, 18.2)), ((18.2, 5.8), (19.9, 4.1)),
            ]
            for ray in rays { line(&path, ray.0, ray.1) }

        case .notebooks:
            path.addRoundedRect(in: CGRect(x: rect.minX + 7 * u, y: rect.minY + 3.2 * u,
                                           width: 12.8 * u, height: 17.6 * u),
                                cornerSize: CGSize(width: 1.6 * u, height: 1.6 * u))
            line(&path, (7, 3.2), (7, 20.8))
            for y in [6.4, 10.6, 14.8] as [CGFloat] { line(&path, (4.2, y), (8.2, y)) }
            line(&path, (11, 8), (16.6, 8))
            line(&path, (11, 12), (16.6, 12))

        case .memory:
            path.addPath(circle(12, 4.6, 2.6))
            path.addPath(circle(5.2, 14, 2.6))
            path.addPath(circle(18.8, 14, 2.6))
            path.addPath(circle(12, 20.6, 2.2))
            line(&path, (10.4, 6.8), (6.8, 11.9))
            line(&path, (13.6, 6.8), (17.2, 11.9))
            line(&path, (6.9, 15.9), (10.4, 19.0))
            line(&path, (17.1, 15.9), (13.6, 19.0))

        case .review:
            path.addRoundedRect(in: CGRect(x: rect.minX + 6.6 * u, y: rect.minY + 3.4 * u,
                                           width: 14.2 * u, height: 13.4 * u),
                                cornerSize: CGSize(width: 2.2 * u, height: 2.2 * u))
            path.move(to: p(17, 20.6))
            path.addLine(to: p(5.4, 20.6))
            path.addLine(to: p(3.2, 18.4))
            path.addLine(to: p(3.2, 7.2))
            line(&path, (10.6, 8.2), (16.8, 8.2))
            line(&path, (10.6, 12), (14.2, 12))

        case .cards:
            path.addRoundedRect(in: CGRect(x: rect.minX + 3.6 * u, y: rect.minY + 3.4 * u,
                                           width: 16.8 * u, height: 17.2 * u),
                                cornerSize: CGSize(width: 2.4 * u, height: 2.4 * u))
            // Etoile a cinq branches du prototype.
            let star: [(CGFloat, CGFloat)] = [
                (12, 7.6), (13.6, 10.9), (17.2, 11.4), (14.6, 13.9),
                (15.2, 17.5), (12, 15.8), (8.8, 17.5), (9.4, 13.9),
                (6.8, 11.4), (10.4, 10.9),
            ]
            path.move(to: p(star[0].0, star[0].1))
            for pt in star.dropFirst() { path.addLine(to: p(pt.0, pt.1)) }
            path.closeSubpath()
        }
        return path
    }
}
