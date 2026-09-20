import SwiftUI

/// Des elements qui passent a la ligne quand la largeur manque.
///
/// Le panneau des pages fait cent soixante-huit points : une rangee
/// horizontale y cache tout ce qui depasse, et un intercalaire qu'il faut
/// aller chercher en faisant defiler n'est plus un intercalaire. On prend une
/// ligne de plus, et on voit tout.
struct WrapLayout: Layout {
    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews,
                      cache: inout ()) -> CGSize {
        let limit = proposal.width ?? .infinity
        var width: CGFloat = 0, x: CGFloat = 0, y: CGFloat = 0, line: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > limit {
                width = max(width, x - spacing)
                y += line + lineSpacing
                x = 0
                line = 0
            }
            x += size.width + spacing
            line = max(line, size.height)
        }
        return CGSize(width: min(max(width, x - spacing), limit), height: y + line)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize,
                       subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, line: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                y += line + lineSpacing
                x = bounds.minX
                line = 0
            }
            view.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: .unspecified)
            x += size.width + spacing
            line = max(line, size.height)
        }
    }
}
