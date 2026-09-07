import SwiftUI

/// Les cinq destinations du rail. Cinq et pas plus : ce sont les endroits ou
/// l'on va plusieurs fois par jour. Tout le reste s'atteint depuis l'accueil ou
/// depuis un cahier — un rail a neuf onglets serait illisible.
enum RailTab: String, CaseIterable, Hashable {
    case day, notebooks, memory, review, cards

    var label: String {
        switch self {
        case .day:       "JOUR"
        case .notebooks: "CAHIERS"
        case .memory:    "MÉMOIRE"
        case .review:    "RÉVISER"
        case .cards:     "FICHES"
        }
    }
    var icon: RailIcon.Kind {
        switch self {
        case .day:       .day
        case .notebooks: .notebooks
        case .memory:    .memory
        case .review:    .review
        case .cards:     .cards
        }
    }
    /// Seuls les cahiers existent a l'etape 1. Les autres sont annonces plutot
    /// que caches : le rail dit ou va l'application.
    var isAvailable: Bool { self != .cards }
}

/// Rail de navigation — 104 px, graphite, du haut au bas de l'ecran.
struct RailView: View {
    @Binding var tab: RailTab
    var avatarLetter: String = "K"

    static let width: CGFloat = 104

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 14) {
                logo
                VStack(spacing: 5) {
                    ForEach(RailTab.allCases, id: \.self) { item in
                        tabButton(item)
                    }
                }
            }
            Spacer(minLength: 0)
            avatar
        }
        .padding(.vertical, 20)
        .frame(width: Self.width)
        .frame(maxHeight: .infinity)
        .background(K.ink)
    }

    private var logo: some View {
        RoundedRectangle(cornerRadius: 15, style: .continuous)
            .fill(K.brand)
            .frame(width: 48, height: 48)
            .overlay(
                Text("K")
                    .font(KFont.display(30))
                    .tracking(-0.6)
                    .foregroundStyle(K.paperAlt)
                    .offset(y: -3)
            )
    }

    private func tabButton(_ item: RailTab) -> some View {
        let isActive = tab == item
        let tint: Color = isActive ? K.paperAlt : K.paperAlt.opacity(0.55)
        return Button {
            guard item.isAvailable else { return }
            tab = item
        } label: {
            VStack(spacing: 5) {
                RailIcon(kind: item.icon)
                    .stroke(tint, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .frame(width: 23, height: 23)
                Text(item.label)
                    .font(KFont.body(10.5, weight: .extraBold))
                    .tracking(0.5)
                    .foregroundStyle(tint)
            }
            .frame(width: 80)
            .padding(.vertical, 10)
            .background(isActive ? K.brand : .clear,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(item.isAvailable ? 1 : 0.38)
        }
        .buttonStyle(.plain)
        .disabled(!item.isAvailable)
        .accessibilityLabel(item.label.capitalized)
        .accessibilityHint(item.isAvailable ? "" : "Bientot disponible")
    }

    private var avatar: some View {
        Circle()
            .fill(K.reward)
            .frame(width: 42, height: 42)
            .overlay(Circle().strokeBorder(K.paperAlt, lineWidth: 3))
            .overlay(
                Text(avatarLetter)
                    .font(KFont.display(16))
                    .foregroundStyle(K.ink)
            )
    }
}
