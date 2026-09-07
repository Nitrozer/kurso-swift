import SwiftUI
import SwiftData
import KursoCore
import KursoModels

/// La carte du semestre — l'onglet MÉMOIRE.
///
/// Ecran sombre, contrairement au reste : c'est une vue d'ensemble qu'on
/// consulte, pas une surface sur laquelle on écrit. Les pages y sont rangées
/// par leur chaîne chronologique, celle que le rattachement construit tout seul.
struct MemoryMapView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Course.name) private var courses: [Course]
    @Query(sort: \Page.createdAt) private var pages: [Page]

    @State private var selectedCourseID: UUID?
    @State private var selectedPageID: UUID?

    var body: some View {
        HStack(spacing: 0) {
            courseColumn
            if selectedCourse != nil {
                pageColumn
                detailColumn
            } else {
                emptyCenter
            }
        }
        .background(K.ink)
        .task { if selectedCourseID == nil { selectedCourseID = courses.first?.id } }
    }

    // MARK: Colonne des matières

    private var courseColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            MetaText("Mes cours · choisis une matière", color: K.paperAlt.opacity(0.45))
                .padding(.horizontal, 18)
                .padding(.top, 22)
                .padding(.bottom, 14)

            ScrollView {
                VStack(spacing: 6) {
                    ForEach(courses) { course in
                        courseRow(course)
                    }
                }
                .padding(.horizontal, 12)
            }
            .scrollIndicators(.hidden)
            Spacer(minLength: 0)
        }
        .frame(width: 250)
    }

    private func courseRow(_ course: Course) -> some View {
        let isActive = selectedCourseID == course.id
        let percent = acquisition(of: course)
        return Button { selectedCourseID = course.id; selectedPageID = nil } label: {
            HStack(spacing: 10) {
                Text(course.name)
                    .font(KFont.body(13.5, weight: .extraBold))
                    .foregroundStyle(isActive ? K.paperAlt : K.paperAlt.opacity(0.7))
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text(percent == nil ? "—" : "\(Int(percent! * 100)) %")
                    .font(KFont.mono(10.5))
                    .foregroundStyle(isActive ? K.paperAlt : K.paperAlt.opacity(0.5))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(isActive ? K.brand : .clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: Colonne des pages

    private var pageColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                DisplayText(selectedCourse?.name ?? "", size: 26, color: K.paperAlt)
                MetaText(summary, color: K.paperAlt.opacity(0.5))
            }
            .padding(.horizontal, 22)
            .padding(.top, 22)
            .padding(.bottom, 16)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(coursePages) { page in
                        pageRow(page)
                    }
                    if coursePages.isEmpty {
                        Text("Aucune page dans cette matière pour l'instant.")
                            .font(KFont.body(12.5, weight: .bold))
                            .foregroundStyle(K.paperAlt.opacity(0.5))
                            .padding(.top, 12)
                    }
                }
                .padding(.horizontal, 16)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity)
    }

    private func pageRow(_ page: Page) -> some View {
        let state = freshnessState(of: page)
        let value = freshnessValue(of: page)
        return Button { selectedPageID = page.id } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(color(for: state))
                    .frame(width: 11, height: 11)
                VStack(alignment: .leading, spacing: 2) {
                    Text(page.title.isEmpty ? "Sans titre" : page.title)
                        .font(KFont.body(13, weight: .extraBold))
                        .foregroundStyle(K.paperAlt)
                        .lineLimit(1)
                    Text("\(page.createdAt.formatted(.dateTime.day().month(.twoDigits))) · \(Int(value * 100)) % · \(state.rawValue)")
                        .font(KFont.mono(9.5))
                        .foregroundStyle(K.paperAlt.opacity(0.5))
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(selectedPageID == page.id ? K.paperAlt.opacity(0.09) : .clear,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: Panneau de droite

    private var detailColumn: some View {
        VStack(alignment: .leading, spacing: 14) {
            MetaText("Mémoire", color: K.paperAlt.opacity(0.45))

            if let page = selectedPage {
                VStack(alignment: .leading, spacing: 6) {
                    Text(page.title.isEmpty ? "Sans titre" : page.title)
                        .font(KFont.body(15, weight: .extraBold))
                        .foregroundStyle(K.paperAlt)
                    Text("\((page.cards ?? []).count) carte(s) · \(page.writingSeconds / 60) min d'écriture")
                        .font(KFont.mono(10))
                        .foregroundStyle(K.paperAlt.opacity(0.55))
                }
            } else {
                Text("Choisis une page pour voir son état.")
                    .font(KFont.body(12.5, weight: .bold))
                    .foregroundStyle(K.paperAlt.opacity(0.5))
            }

            Divider().overlay(K.paperAlt.opacity(0.15))

            // Le mot accompagne toujours la couleur (§3).
            VStack(alignment: .leading, spacing: 9) {
                legend(.acquired, "à jour")
                legend(.toReview, "à revoir bientôt")
                legend(.endangered, "à sauver")
                legend(.draft, "sans carte")
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(width: 230)
    }

    private func legend(_ state: Freshness.State, _ hint: String) -> some View {
        HStack(spacing: 9) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(color(for: state))
                .frame(width: 11, height: 11)
            VStack(alignment: .leading, spacing: 1) {
                Text(state.rawValue)
                    .font(KFont.body(12, weight: .extraBold))
                    .foregroundStyle(K.paperAlt)
                Text(hint)
                    .font(KFont.body(10.5, weight: .bold))
                    .foregroundStyle(K.paperAlt.opacity(0.45))
            }
        }
    }

    private var emptyCenter: some View {
        VStack(spacing: 10) {
            DisplayText("Rien à cartographier", size: 22, color: K.paperAlt)
            Text("Importe ton emploi du temps et écris quelques pages : la carte se construit toute seule.")
                .font(KFont.body(13, weight: .bold))
                .foregroundStyle(K.paperAlt.opacity(0.55))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 340)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Calculs

    private var selectedCourse: Course? { courses.first { $0.id == selectedCourseID } }
    private var selectedPage: Page? { pages.first { $0.id == selectedPageID } }

    private var coursePages: [Page] {
        guard let id = selectedCourseID else { return [] }
        return pages.filter { $0.course?.id == id }.sorted { $0.createdAt > $1.createdAt }
    }

    private var summary: String {
        let count = coursePages.count
        let cards = coursePages.reduce(0) { $0 + ($1.cards ?? []).count }
        return "\(count) page\(count > 1 ? "s" : "") · \(cards) carte\(cards > 1 ? "s" : "")"
    }

    private func cardStates(of page: Page) -> [Freshness.CardState] {
        (page.cards ?? []).map { Freshness.CardState(dueAt: $0.dueAt, interval: $0.interval) }
    }

    private func freshnessValue(of page: Page) -> Double {
        Freshness.compute(cards: cardStates(of: page))
    }

    private func freshnessState(of page: Page) -> Freshness.State {
        Freshness.state(cards: cardStates(of: page))
    }

    /// Le pourcentage d'une matiere : la moyenne de ses pages qui portent des
    /// cartes. Les brouillons ne comptent pas — ils gonfleraient le score sans
    /// que rien n'ait ete revise.
    private func acquisition(of course: Course) -> Double? {
        let withCards = pages.filter { $0.course?.id == course.id && !($0.cards ?? []).isEmpty }
        guard !withCards.isEmpty else { return nil }
        return withCards.map(freshnessValue).reduce(0, +) / Double(withCards.count)
    }

    private func color(for state: Freshness.State) -> Color {
        switch state {
        case .acquired:   K.success
        case .toReview:   K.fadedInk
        case .endangered: K.endangered
        case .draft:      K.pendingLine
        }
    }
}
