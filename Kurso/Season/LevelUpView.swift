import SwiftUI
import KursoCore

/// Le passage de niveau, tel que la maquette `shots/niveau.png` le fixe.
///
/// Fond bleu plein, pastille jaune, le chiffre en grand, Gribou qui vient de
/// se faire tailler, la ligne du coffre, puis CONTINUER. Le coffre n'est pas
/// un ecran a lui seul : c'est une ligne dans ce moment-la.
///
/// « Crayon taille » n'est pas une formule : la mine de Gribou s'use avec les
/// heures ecrites et se remet a zero ici (§9). La progression se lit sur le
/// personnage, pas dans une barre.
struct LevelUpView: View {
    let celebration: ChestStore.Celebration
    var onContinue: () -> Void

    var body: some View {
        ZStack {
            K.brand.ignoresSafeArea()
            confetti
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var content: some View {
        VStack(spacing: 0) {
            Text("NIVEAU SUPÉRIEUR")
                .font(KFont.body(12.5, weight: .extraBold))
                .tracking(1.4)
                .foregroundStyle(K.ink)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(K.reward, in: Capsule())
                .overlay(Capsule().strokeBorder(K.ink, lineWidth: 3))

            Text("\(celebration.level)")
                .font(KFont.display(76))
                .foregroundStyle(K.paperAlt)
                .padding(.top, 12)

            Text("Crayon taillé")
                .font(KFont.display(21))
                .foregroundStyle(K.paperAlt.opacity(0.82))
                .padding(.top, 2)

            GribouView(mood: .fier, size: 260)
                .padding(.top, 14)

            chestRow
                .padding(.top, 22)

            Button("CONTINUER") { onContinue() }
                .buttonStyle(StickerButtonStyle(kind: .primary))
                .padding(.top, 12)
        }
        // Un bloc centre, pas une colonne etiree : sur un iPad les ressorts
        // ecartaient Gribou du coffre au point de casser le moment.
        .padding(26)
        .frame(maxWidth: 520)
    }

    /// La ligne du coffre : ce qu'il contenait a gauche, l'XP du jour a droite.
    private var chestRow: some View {
        HStack(spacing: 13) {
            ChestGlyph()
                .frame(width: 44, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(celebration.rewards.count > 1 ? "\(celebration.rewards.count) coffres ouverts" : "Coffre ouvert")
                    .font(KFont.display(17))
                    .foregroundStyle(K.ink)
                Text(contents)
                    .font(KFont.body(12.5, weight: .bold))
                    .foregroundStyle(K.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 0) {
                Text("+\(celebration.xpToday)")
                    .font(KFont.display(22))
                    .foregroundStyle(K.brand)
                Text("XP DU JOUR")
                    .font(KFont.body(9, weight: .extraBold))
                    .tracking(0.8)
                    .foregroundStyle(K.inkSoft)
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
        .background(K.paperAlt, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(K.ink, lineWidth: 3))
    }

    /// Le contenu enonce a plat, dans l'ordre de la maquette.
    private var contents: String {
        var parts: [String] = []
        if celebration.freezes > 0 {
            parts.append(celebration.freezes > 1 ? "\(celebration.freezes) gels de série" : "1 gel de série")
        }
        let covers = celebration.covers
        if !covers.isEmpty {
            let names = covers.map { "« \($0.label) »" }.joined(separator: ", ")
            parts.append(covers.count > 1 ? "couvertures \(names)" : "couverture \(names)")
        }
        if celebration.shavings > 0 {
            parts.append("\(celebration.shavings) copeaux")
        }
        // Un coffre vide ne devrait pas s'ouvrir, mais la ligne doit rester lisible.
        return parts.isEmpty ? "Rien de neuf cette fois" : parts.joined(separator: " · ")
    }

    /// Les eclats qui flottent derriere. Poses une fois, pas animes : le §12
    /// interdit de faire attendre devant une animation.
    private var confetti: some View {
        GeometryReader { geo in
            ForEach(Array(Self.specks.enumerated()), id: \.offset) { _, speck in
                RoundedRectangle(cornerRadius: speck.isRound ? 5 : 2, style: .continuous)
                    .fill(speck.color)
                    .frame(width: speck.size, height: speck.size)
                    .position(x: geo.size.width * speck.x, y: geo.size.height * speck.y)
            }
        }
        .allowsHitTesting(false)
    }

    private struct Speck {
        var x: Double, y: Double, size: CGFloat
        var isRound: Bool
        var color: Color
    }

    private static let specks: [Speck] = [
        .init(x: 0.21, y: 0.12, size: 7,  isRound: true,  color: K.paperAlt.opacity(0.5)),
        .init(x: 0.87, y: 0.16, size: 9,  isRound: true,  color: K.paperAlt.opacity(0.7)),
        .init(x: 0.06, y: 0.36, size: 6,  isRound: true,  color: K.paperAlt.opacity(0.35)),
        .init(x: 0.93, y: 0.32, size: 8,  isRound: false, color: K.reward.opacity(0.85)),
        .init(x: 0.85, y: 0.46, size: 11, isRound: false, color: K.reward),
        .init(x: 0.13, y: 0.55, size: 7,  isRound: false, color: K.paperAlt.opacity(0.3)),
    ]
}

/// Un coffre dessine, pas une image : la direction artistique est faite de
/// formes epaisses cernees d'encre, et un PNG jurerait a cote.
struct ChestGlyph: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            // Le couvercle, ouvert et bascule en arriere.
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(K.reward)
                .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(K.ink, lineWidth: 2.5))
                .frame(width: 34, height: 12)
                .rotationEffect(.degrees(-24), anchor: .bottomLeading)
                .offset(x: 2, y: -22)

            // La caisse.
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(K.reward)
                .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(K.ink, lineWidth: 2.5))
                .frame(width: 38, height: 21)
                .overlay(
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(K.paperAlt)
                        .frame(width: 11, height: 12)
                        .overlay(RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .strokeBorder(K.ink, lineWidth: 2.5))
                )
        }
        .frame(width: 44, height: 36, alignment: .bottom)
    }
}
