import SwiftUI

/// Les glyphes sont DESSINES, jamais empruntes a une bibliotheque : « toutes les
/// icones sont dessinees au meme trait, un jeu generique annule tout le reste ».
///
/// Trait de 3, extremites arrondies — la meme main que la coche.
private let glyphStroke = StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)

struct PlusGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}

/// Le crayon : la signature de l'app, reduite a trois traits.
struct PencilGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height)
        var p = Path()
        // Corps
        p.move(to: CGPoint(x: rect.minX + s * 0.20, y: rect.maxY - s * 0.18))
        p.addLine(to: CGPoint(x: rect.minX + s * 0.72, y: rect.minY + s * 0.16))
        // Pointe
        p.move(to: CGPoint(x: rect.minX + s * 0.14, y: rect.maxY - s * 0.10))
        p.addLine(to: CGPoint(x: rect.minX + s * 0.30, y: rect.maxY - s * 0.24))
        // Virole
        p.move(to: CGPoint(x: rect.minX + s * 0.52, y: rect.minY + s * 0.30))
        p.addLine(to: CGPoint(x: rect.minX + s * 0.66, y: rect.minY + s * 0.44))
        return p
    }
}

struct Glyph: View {
    enum Kind { case plus, pencil }
    var kind: Kind
    var size: CGFloat = 18
    var color: Color = K.ink

    var body: some View {
        Group {
            switch kind {
            case .plus:   PlusGlyph().stroke(color, style: glyphStroke)
            case .pencil: PencilGlyph().stroke(color, style: glyphStroke)
            }
        }
        .frame(width: size, height: size)
    }
}
