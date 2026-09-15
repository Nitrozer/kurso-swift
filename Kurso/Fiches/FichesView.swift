import SwiftUI
import SwiftData
import KursoCore
import KursoModels

/// Les fiches du semestre (§11, etape 4).
///
/// Une fiche par page : on la gagne en maitrisant ce qu'on y a ecrit. Rien ne
/// s'achete et rien ne se tire au sort — §12 interdit les achats qui font
/// progresser, et une collection qui se paie n'apprend rien.
struct FichesView: View {
    @Query(sort: \Page.createdAt, order: .reverse) private var pages: [Page]
    @State private var filter: Fiche.Rarity?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if fiches.isEmpty {
                EmptyState(title: "Aucune fiche",
                           message: "Écris une page, capture deux ou trois cartes : la fiche apparaîtra ici.")
                    .frame(maxHeight: .infinity)
            } else {
                grid
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(K.ink)
    }

    // MARK: En-tete

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Fiches du semestre")
                    .font(KFont.display(30))
                    .foregroundStyle(K.paperAlt)
                Text(Fiche.summary(fiches.map(\.rarity)))
                    .font(KFont.mono(11))
                    .tracking(1)
                    .foregroundStyle(K.paperAlt.opacity(0.55))
            }
            Spacer(minLength: 16)
            HStack(spacing: 9) {
                ForEach([Fiche.Rarity.gold, .rare, .common], id: \.self) { rarity in
                    filterPill(rarity)
                }
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 26)
        .padding(.bottom, 20)
    }

    private func filterPill(_ rarity: Fiche.Rarity) -> some View {
        let count = fiches.filter { $0.rarity == rarity }.count
        let isActive = filter == rarity
        return Button {
            filter = isActive ? nil : rarity
        } label: {
            Text("\(rarity.shortLabel) \(count)")
                .font(KFont.body(11.5, weight: .extraBold))
                .foregroundStyle(tint(rarity))
                .padding(.horizontal, 13).padding(.vertical, 7)
                .background(isActive ? tint(rarity).opacity(0.16) : .clear, in: Capsule())
                .overlay(Capsule().strokeBorder(tint(rarity), lineWidth: isActive ? 2.5 : 1.8))
        }
        .buttonStyle(.plain)
    }

    // MARK: La planche

    private var grid: some View {
        ScrollView {
            GribouBubble(tips: ficheTips, mood: .fier)
                .padding(.bottom, 14)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 16)], spacing: 16) {
                ForEach(shown, id: \.id) { fiche in
                    card(fiche)
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
    }

    private func card(_ fiche: Entry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(fiche.rarity.label)
                .font(KFont.mono(9.5))
                .tracking(1)
                .foregroundStyle(tint(fiche.rarity).opacity(fiche.rarity == .locked ? 0.5 : 0.9))

            Text(fiche.title)
                .font(KFont.display(19))
                .foregroundStyle(K.paperAlt.opacity(fiche.rarity == .locked ? 0.4 : 1))
                .lineLimit(2)

            Text(fiche.subtitle)
                .font(KFont.body(12.5, weight: .bold))
                .foregroundStyle(K.paperAlt.opacity(fiche.rarity == .locked ? 0.3 : 0.72))
                .lineLimit(2)

            Spacer(minLength: 18)

            HStack {
                HStack(spacing: 5) {
                    ForEach(0..<3, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                            .fill(index < fiche.rarity.dots
                                  ? tint(fiche.rarity)
                                  : K.paperAlt.opacity(0.18))
                            .frame(width: 9, height: 9)
                    }
                }
                Spacer()
                if fiche.rarity == .locked {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .strokeBorder(K.paperAlt.opacity(0.3), lineWidth: 2)
                        .frame(width: 15, height: 15)
                }
            }
        }
        .padding(18)
        .frame(height: 176, alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(fill(fiche.rarity), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(border(fiche.rarity), lineWidth: fiche.rarity == .gold || fiche.rarity == .rare ? 2.5 : 1.5))
    }

    // MARK: Couleurs

    private func tint(_ rarity: Fiche.Rarity) -> Color {
        switch rarity {
        case .gold:   K.reward
        case .rare:   Color(red: 0.62, green: 0.71, blue: 1)
        case .common: K.paperAlt.opacity(0.6)
        case .locked: K.paperAlt.opacity(0.45)
        }
    }

    private func fill(_ rarity: Fiche.Rarity) -> some ShapeStyle {
        switch rarity {
        case .gold:
            AnyShapeStyle(LinearGradient(
                colors: [Color(red: 0.45, green: 0.36, blue: 0.10),
                         Color(red: 0.62, green: 0.50, blue: 0.14)],
                startPoint: .bottomLeading, endPoint: .topTrailing))
        case .rare:
            AnyShapeStyle(Color(red: 0.16, green: 0.26, blue: 0.72))
        default:
            AnyShapeStyle(K.paperAlt.opacity(0.06))
        }
    }

    private func border(_ rarity: Fiche.Rarity) -> Color {
        switch rarity {
        case .gold:   K.reward
        case .rare:   Color(red: 0.42, green: 0.55, blue: 1)
        default:      K.paperAlt.opacity(0.14)
        }
    }

    // MARK: Donnees

    struct Entry: Identifiable {
        let id: UUID
        let title: String
        let subtitle: String
        let rarity: Fiche.Rarity
    }

    /// Ce que Gribou pourrait dire devant la collection.
    private var ficheTips: [GribouAdvice.Tip] {
        var tips: [GribouAdvice.Tip] = []
        let locked = fiches.filter { $0.rarity == .locked }.count
        let gold = fiches.filter { $0.rarity == .gold }.count

        if locked > 0 {
            tips.append(.init(
                id: "fiches.verrouillees",
                kind: .action,
                text: locked == 1
                    ? "Une fiche reste verrouillée. Capture une carte dans ce nœud et elle s'ouvre."
                    : "\(locked) fiches restent verrouillées. Il suffit d'une carte capturée par nœud."))
        }

        tips.append(.init(
            id: "fiches.or",
            kind: .mechanic,
            text: "Une fiche passe en or quand son nœud est su entièrement, sans une seule faute. C'est le seul moyen — elle ne s'achète pas."))

        if gold > 0 {
            tips.append(.init(
                id: "fiches.bravo",
                kind: .cheer,
                text: gold == 1 ? "Une fiche en or. C'est un nœud su sans faute." : "\(gold) fiches en or dans ta collection."))
        }
        return tips
    }

    private var shown: [Entry] {
        guard let filter else { return fiches }
        return fiches.filter { $0.rarity == filter }
    }

    private var fiches: [Entry] {
        // Un PDF ne vaut qu'une fiche, comme il ne vaut qu'une entree ailleurs.
        Page.collapsingSlides(pages).map { page in
            let cards = page.cards ?? []
            let acquired = cards.filter {
                Fiche.isAcquired(interval: $0.interval, dueAt: $0.dueAt)
            }.count
            let lapses = cards.reduce(0) { $0 + $1.lapses }
            return Entry(
                id: page.id,
                title: page.title.isEmpty ? "Page sans titre" : PageTitle.withoutSlideNumber(page.title),
                subtitle: subtitle(for: page, cardCount: cards.count),
                rarity: Fiche.rarity(cardCount: cards.count, acquired: acquired, lapses: lapses)
            )
        }
    }

    private func subtitle(for page: Page, cardCount: Int) -> String {
        if cardCount == 0 {
            return page.course.map { "Capture une carte dans \($0.name)" } ?? "Capture une carte"
        }
        if let course = page.course { return "\(course.name) · \(cardCount) cartes" }
        return "\(cardCount) cartes"
    }
}
