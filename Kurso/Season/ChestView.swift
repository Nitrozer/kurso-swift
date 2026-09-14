import SwiftUI
import KursoCore

/// Le coffre de passage de niveau (§9).
///
/// Il ne s'achete pas et ne se joue pas : le §12 a retire le pari de copeaux.
/// Il s'ouvre donc sans suspense et sans animation d'attente — un coffre a
/// surprise donnerait une raison de rouvrir l'application pour autre chose que
/// travailler.
struct ChestView: View {
    let rewards: [ChestStore.Reward]
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            ChestGlyph()
                .frame(width: 104, height: 84)

            DisplayText(title, size: 28)
                .multilineTextAlignment(.center)

            VStack(spacing: 8) {
                ForEach(rewards, id: \.level) { row($0) }
            }

            Text("Les coffres ne contiennent que de l'apparence. Rien ici ne fait réviser plus vite.")
                .font(KFont.body(12, weight: .bold))
                .foregroundStyle(K.inkSoft)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button("Prendre") { onClose() }
                .buttonStyle(StickerButtonStyle(kind: .primary))
                .frame(maxWidth: 280)
        }
        .padding(28)
        .frame(maxWidth: 460)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(K.paper)
    }

    /// Plusieurs coffres quand on monte de deux niveaux d'un coup : ils sont
    /// rattrapes, pas perdus.
    private var title: String {
        rewards.count > 1
            ? "\(rewards.count) coffres"
            : "Coffre — niveau \(rewards.first?.level ?? 1)"
    }

    private func row(_ reward: ChestStore.Reward) -> some View {
        HStack(spacing: 12) {
            Text("\(reward.level)")
                .font(KFont.display(16))
                .foregroundStyle(K.ink)
                .frame(width: 34, height: 34)
                .background(K.reward, in: Circle())
                .overlay(Circle().strokeBorder(K.ink, lineWidth: 2.5))

            VStack(alignment: .leading, spacing: 2) {
                Text("\(reward.shavings) copeaux")
                    .font(KFont.body(14, weight: .extraBold))
                    .foregroundStyle(K.ink)
                if let cover = reward.cover {
                    Text("Couverture « \(cover.label) »")
                        .font(KFont.body(12, weight: .bold))
                        .foregroundStyle(K.inkBody)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(K.paperAlt, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(K.ink, lineWidth: 2.5))
    }
}

/// Un coffre dessine, pas une image : la direction artistique est faite de
/// formes epaisses cernees d'encre, et un PNG jurerait a cote.
private struct ChestGlyph: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(K.brand)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(K.ink, lineWidth: 3))

            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(K.reward)
                    .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(K.ink, lineWidth: 3))
                    .frame(height: 34)
                Spacer(minLength: 0)
            }
            .padding(4)

            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(K.paperAlt)
                .frame(width: 18, height: 24)
                .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(K.ink, lineWidth: 3))
                .offset(y: 8)
        }
    }
}
