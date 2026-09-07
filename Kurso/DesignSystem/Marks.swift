import SwiftUI

/// La coche est DESSINEE, jamais le caractere « ✓ » d'une police : trait de 3,6,
/// extremites arrondies. C'est ce qui la rend solidaire du reste du trait.
struct Checkmark: Shape {
    func path(in rect: CGRect) -> Path {
        // Trace normalise sur la boite 24×24 de la maquette, puis mis a l'echelle.
        let s = min(rect.width, rect.height) / 24
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 5 * s, y: rect.minY + 12.8 * s))
        path.addLine(to: CGPoint(x: rect.minX + 9.6 * s, y: rect.minY + 17.4 * s))
        path.addLine(to: CGPoint(x: rect.minX + 19 * s, y: rect.minY + 7.4 * s))
        return path
    }
}

/// Rond pour une quete, carre pour une tache — la forme porte le sens.
struct CheckBadge: View {
    enum Kind { case quest, task }

    var kind: Kind = .task
    var isChecked: Bool
    var size: CGFloat = 26

    var body: some View {
        ZStack {
            switch kind {
            case .quest:
                Circle().fill(isChecked ? K.success : .clear)
                Circle().strokeBorder(K.ink, lineWidth: 2.5)
            case .task:
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isChecked ? K.success : .clear)
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(K.ink, lineWidth: 3)
            }

            if isChecked {
                Checkmark()
                    .stroke(K.paperAlt, style: StrokeStyle(lineWidth: 3.6, lineCap: .round, lineJoin: .round))
                    .frame(width: size * 0.54, height: size * 0.54)
            }
        }
        .frame(width: size, height: size)
    }
}
