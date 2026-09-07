#if os(iOS)
import UIKit

/// Le papier : lignes, marge et perforations.
///
/// Vue UIKit placee DANS le canevas, sous les traits, plutot que derriere lui
/// en SwiftUI : ainsi elle defile et zoome avec l'ecriture. Un fond pose
/// derriere resterait immobile pendant qu'on fait glisser la page.
final class PaperView: UIView {

    enum Template { case blank, ruled, grid, dotted }

    var template: Template = .ruled { didSet { setNeedsDisplay() } }

    /// Interligne. 32 pt laisse la place a une ecriture normale au stylet.
    private let lineSpacing: CGFloat = 32
    private let marginX: CGFloat = 96

    private let paper = UIColor(red: 0.980, green: 0.984, blue: 1.0, alpha: 1)
    private let line = UIColor(red: 0.847, green: 0.867, blue: 0.937, alpha: 1)
    private let margin = UIColor(red: 1.0, green: 0.612, blue: 0.639, alpha: 0.55)

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = paper
        contentMode = .redraw
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        paper.setFill()
        context.fill(bounds)
        guard template != .blank else { return }

        context.setLineWidth(1)
        line.setStroke()

        if template == .dotted {
            line.setFill()
            var y = lineSpacing
            while y < bounds.height {
                var x = lineSpacing
                while x < bounds.width {
                    context.fillEllipse(in: CGRect(x: x - 1, y: y - 1, width: 2, height: 2))
                    x += lineSpacing
                }
                y += lineSpacing
            }
            return
        }

        var y = lineSpacing
        while y < bounds.height {
            context.move(to: CGPoint(x: 0, y: y))
            context.addLine(to: CGPoint(x: bounds.width, y: y))
            y += lineSpacing
        }
        context.strokePath()

        if template == .grid {
            var x = lineSpacing
            while x < bounds.width {
                context.move(to: CGPoint(x: x, y: 0))
                context.addLine(to: CGPoint(x: x, y: bounds.height))
                x += lineSpacing
            }
            context.strokePath()
        }

        // La marge rouge du cahier francais.
        if template == .ruled {
            margin.setStroke()
            context.setLineWidth(1.5)
            context.move(to: CGPoint(x: marginX, y: 0))
            context.addLine(to: CGPoint(x: marginX, y: bounds.height))
            context.strokePath()
        }
    }
}
#endif
