import SwiftUI
import SwiftData
import KursoCore
import KursoModels

/// Le budget d'apparitions de Gribou, pour la session en cours (§12).
///
/// En memoire et non en base : une « session » est une utilisation de
/// l'application, pas une donnee a conserver. Fermer l'app remet le compteur
/// a zero, ce qui est exactement le sens de la regle.
@MainActor
@Observable
final class AdviceBudget {
    static let shared = AdviceBudget()
    private(set) var spent = 0
    private var consumed: Set<String> = []

    /// Consomme une apparition pour ce conseil, une seule fois par session.
    func consume(_ id: String) {
        guard !consumed.contains(id) else { return }
        consumed.insert(id)
        spent += 1
    }

    private init() {}
}

/// Gribou et sa bulle, quand il a quelque chose a dire.
///
/// La vue se charge de tout : elle choisit le meilleur conseil parmi ceux que
/// l'ecran propose, verifie le budget, et disparait si elle n'a rien a dire.
/// Un ecran n'a donc qu'a lister ce qu'il POURRAIT dire.
struct GribouBubble: View {
    let tips: [GribouAdvice.Tip]
    var mood: GribouMood = .idle

    @Environment(\.modelContext) private var context
    @State private var budget = AdviceBudget.shared
    @State private var chosen: GribouAdvice.Tip?

    var body: some View {
        // Surtout pas un `Group` ici : SwiftUI propage ses modificateurs a ses
        // ENFANTS, et un Group vide n'en a aucun — le `.task` ne s'attachait
        // donc a rien et le conseil n'etait jamais choisi.
        content
            .task(id: tips.map(\.id).joined()) { pick() }
            .animation(.snappy(duration: 0.3), value: chosen?.id)
    }

    @ViewBuilder private var content: some View {
        if let chosen {
                HStack(alignment: .center, spacing: 0) {
                    GribouView(mood: mood, size: 78)

                    // La pointe de la bulle, tournee vers lui.
                    Triangle()
                        .fill(K.paperAlt)
                        .frame(width: 11, height: 18)
                        .overlay(Triangle().stroke(K.ink, lineWidth: 2.5))
                        .offset(x: 2)
                        .zIndex(1)

                    Text(chosen.text)
                        .font(KFont.body(13, weight: .bold))
                        .foregroundStyle(K.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(K.paperAlt, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(K.ink, lineWidth: 2.5))
                }
                .frame(maxWidth: 640, alignment: .leading)
                .transition(.opacity)
        } else {
            Color.clear.frame(height: 0)
        }
    }

    private func pick() {
        let player = PlayerStore.current(context)
        guard let tip = GribouAdvice.choose(
            from: tips,
            spent: budget.spent,
            seen: Set(player.seenTips)
        ) else {
            chosen = nil
            return
        }
        chosen = tip
        budget.consume(tip.id)

        // Une mecanique expliquee ne se reexplique jamais, meme dans six mois.
        if tip.isOnceInALifetime, !player.seenTips.contains(tip.id) {
            player.seenTips.append(tip.id)
            try? context.save()
        }
    }
}

/// La pointe de la bulle. Trois points, pas une image.
private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
