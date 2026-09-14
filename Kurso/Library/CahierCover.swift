import SwiftUI
import KursoCore

/// La couverture d'un cahier : sa couleur, et son motif s'il en a un.
///
/// Tout est trace, rien n'est une image : les motifs restent nets a toute
/// taille et suivent la couleur choisie, sans fichier a livrer.
struct CahierCover: View {
    let color: Color
    let cover: Shop.Cover

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            color
            pattern
            // La tranche, comme un cahier pose de profil.
            Rectangle().fill(K.ink.opacity(0.18))
                .frame(width: 14)
                .frame(maxHeight: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder private var pattern: some View {
        switch cover {
        case .plain:
            EmptyView()
        case .stripes:
            Canvas { context, size in
                var x: CGFloat = -size.height
                while x < size.width {
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: size.height))
                    path.addLine(to: CGPoint(x: x + size.height, y: 0))
                    context.stroke(path, with: .color(.white.opacity(0.16)), lineWidth: 7)
                    x += 18
                }
            }
        case .grid:
            Canvas { context, size in
                var path = Path()
                var v: CGFloat = 0
                while v < size.width { path.move(to: CGPoint(x: v, y: 0)); path.addLine(to: CGPoint(x: v, y: size.height)); v += 16 }
                v = 0
                while v < size.height { path.move(to: CGPoint(x: 0, y: v)); path.addLine(to: CGPoint(x: size.width, y: v)); v += 16 }
                context.stroke(path, with: .color(.white.opacity(0.18)), lineWidth: 1.5)
            }
        case .kraft:
            LinearGradient(colors: [.white.opacity(0.22), .clear, .black.opacity(0.10)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        case .marble:
            Canvas { context, size in
                for index in 0..<7 {
                    var path = Path()
                    let base = size.height * CGFloat(index) / 7
                    path.move(to: CGPoint(x: 0, y: base))
                    path.addCurve(to: CGPoint(x: size.width, y: base + 14),
                                  control1: CGPoint(x: size.width * 0.3, y: base - 22),
                                  control2: CGPoint(x: size.width * 0.7, y: base + 34))
                    context.stroke(path, with: .color(.white.opacity(0.20)), lineWidth: 3)
                }
            }
        }
    }
}
