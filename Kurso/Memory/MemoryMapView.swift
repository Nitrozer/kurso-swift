import SwiftUI
import SwiftData
import KursoCore
import KursoModels

/// La carte du semestre, d'apres `shots/carte-semestre.png`.
///
/// Un graphe, pas une liste : les pages sont des noeuds relies par le lien
/// chronologique (§1), et leur couleur dit l'etat de l'encre (§3). C'est la
/// mecanique signature de Kurso — la rendre en liste a puces la vidait de son
/// sens, puisque tout l'interet est de voir d'un coup d'oeil ou la memoire
/// s'effrite.
struct MemoryMapView: View {
    /// Reviser les cartes d'une page, depuis la carte.
    var onReview: ([UUID]) -> Void = { _ in }

    @Environment(\.modelContext) private var context
    @Query(sort: \Course.name) private var courses: [Course]
    @Query(sort: \Page.createdAt) private var pages: [Page]

    @State private var selectedCourseID: UUID?
    @State private var selectedPageID: UUID?

    private static let nodeSize: CGFloat = 64
    private static let rowHeight: CGFloat = 150

    var body: some View {
        HStack(spacing: 0) {
            graphSide
            Rectangle().fill(K.ink).frame(width: 3)
            detailPanel.frame(width: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(K.ink)
        .task { selectFirstCourse() }
    }

    // MARK: Le graphe

    private var graphSide: some View {
        VStack(spacing: 0) {
            graphHeader
            if layout.nodes.isEmpty {
                emptyMap
            } else {
                ScrollView {
                    graphCanvas
                        .frame(height: max(520, CGFloat(layout.nodes.count) * Self.rowHeight))
                        .padding(.horizontal, 30)
                        .padding(.top, 40)
                        // Le dernier noeud passait sous la barre de legende.
                        .padding(.bottom, 90)
                }
                .scrollIndicators(.hidden)
            }
            legendBar
        }
        .frame(maxWidth: .infinity)
        .background(dottedBackdrop)
    }

    /// Le fond pointille de la maquette. Dessine, pas une image.
    private var dottedBackdrop: some View {
        Canvas { context, size in
            let step: CGFloat = 26
            let dot = Color(white: 1).opacity(0.05)
            var y: CGFloat = step
            while y < size.height {
                var x: CGFloat = step
                while x < size.width {
                    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 2, height: 2)),
                                 with: .color(dot))
                    x += step
                }
                y += step
            }
        }
        .background(K.ink)
    }

    private var graphHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 13) {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(K.cahier(CourseColor.named(selectedCourse?.colorToken ?? "blue")))
                    .frame(width: 36, height: 36)
                    .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(K.ink, lineWidth: 2.5))
                    .overlay(
                        RailIcon(kind: .notebooks)
                            .stroke(K.ink, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                            .frame(width: 17, height: 17)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedCourse?.name ?? "Sans matière")
                        .font(KFont.display(23))
                        .foregroundStyle(K.paperAlt)
                    Text(mapMeta)
                        .font(KFont.mono(10.5))
                        .tracking(1)
                        .foregroundStyle(K.paperAlt.opacity(0.5))
                }
                Spacer(minLength: 0)
            }

            if courses.count > 1 { courseChips }
            GribouBubble(tips: mapTips, mood: .concentre)
        }
        .padding(.horizontal, 28)
        .padding(.top, 22)
        .padding(.bottom, 14)
    }

    private var courseChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(courses) { course in
                    let active = course.id == selectedCourseID
                    Button {
                        selectedCourseID = course.id
                        selectedPageID = nil
                    } label: {
                        Text(course.name)
                            .font(KFont.body(12, weight: .extraBold))
                            .foregroundStyle(active ? K.ink : K.paperAlt.opacity(0.75))
                            .padding(.horizontal, 13)
                            .padding(.vertical, 7)
                            .background(active ? K.reward : .clear, in: Capsule())
                            .overlay(Capsule().strokeBorder(
                                active ? K.ink : K.paperAlt.opacity(0.25), lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    /// Les aretes au fond, les noeuds par-dessus.
    private var graphCanvas: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Canvas { context, size in
                    for edge in layout.edges {
                        guard let from = layout.node(edge.from), let to = layout.node(edge.to) else { continue }
                        var path = Path()
                        path.move(to: point(from, in: size))
                        path.addLine(to: point(to, in: size))
                        context.stroke(path, with: .color(K.paperAlt.opacity(0.28)), lineWidth: 3)
                    }
                }
                ForEach(layout.nodes) { node in
                    nodeView(node)
                        .position(point(node, in: geo.size))
                }
            }
        }
    }

    /// Les positions vont de 0 a 1 ; un cercle centre sur 0 serait coupe en
    /// deux par le bord. On resserre la plage utile.
    private static let inset = 0.08

    private func point(_ node: MemoryMap.Node, in size: CGSize) -> CGPoint {
        let span = 1 - 2 * Self.inset
        return CGPoint(x: (Self.inset + node.x * span) * size.width,
                       y: (Self.inset + node.y * span) * size.height)
    }

    private func nodeView(_ node: MemoryMap.Node) -> some View {
        let selected = node.id == selectedPageID
        return Button {
            selectedPageID = node.id
        } label: {
            VStack(spacing: 7) {
                ZStack {
                    Circle()
                        .fill(node.state == .draft ? Color.clear : tint(node.state))
                        .frame(width: Self.nodeSize, height: Self.nodeSize)
                        .overlay(
                            Circle().strokeBorder(
                                node.state == .draft ? K.paperAlt.opacity(0.4) : K.ink,
                                style: StrokeStyle(lineWidth: 3,
                                                   dash: node.state == .draft ? [5, 5] : [])
                            )
                        )
                    if node.state != .draft {
                        Checkmark()
                            .stroke(K.ink, style: StrokeStyle(lineWidth: 3.4, lineCap: .round, lineJoin: .round))
                            .frame(width: 21, height: 16)
                    }
                }
                .overlay(
                    Circle()
                        .strokeBorder(K.brand, lineWidth: 4)
                        .frame(width: Self.nodeSize + 14, height: Self.nodeSize + 14)
                        .opacity(selected ? 1 : 0)
                )

                VStack(spacing: 3) {
                    Text(node.date.formatted(.dateTime.day().month(.twoDigits)))
                        .font(KFont.mono(9.5))
                        .tracking(0.8)
                        .foregroundStyle(K.paperAlt.opacity(0.5))
                    Text(node.title.isEmpty ? "Sans titre" : node.title)
                        .font(KFont.body(12.5, weight: .extraBold))
                        .foregroundStyle(K.paperAlt)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .frame(width: 150)
                    HStack(spacing: 4) {
                        ForEach(0..<3, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(index < node.dots ? tint(node.state) : K.paperAlt.opacity(0.18))
                                .frame(width: 8, height: 8)
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(node.title), \(node.state.rawValue)")
    }

    private var legendBar: some View {
        // Une legende qui se casse en morceaux (« pres / que / effac / ée »)
        // ne se lit plus : chaque entree tient sur une ligne, et la barre
        // defile si la colonne est trop etroite.
        ScrollView(.horizontal) {
            HStack(spacing: 16) {
                Text("ENCRE")
                    .font(KFont.mono(9.5))
                    .tracking(1.1)
                    .foregroundStyle(K.paperAlt.opacity(0.45))
                    .fixedSize()
                ForEach(Array(MemoryMap.legend.enumerated()), id: \.offset) { _, item in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(item.state == .draft ? .clear : tint(item.state))
                            .frame(width: 11, height: 11)
                            .overlay(Circle().strokeBorder(
                                item.state == .draft ? K.paperAlt.opacity(0.45) : K.ink, lineWidth: 2))
                        Text(item.label)
                            .font(KFont.body(11.5, weight: .bold))
                            .foregroundStyle(K.paperAlt.opacity(0.62))
                            .lineLimit(1)
                            .fixedSize()
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
        // A gauche, le bouton qui replie le rail vient chercher cette barre :
        // on lui laisse la place plutot que de l'ecrire dessous.
        .padding(.leading, 52)
        .padding(.trailing, 28)
        .padding(.vertical, 14)
        .background(K.ink.opacity(0.85))
        .overlay(alignment: .top) {
            Rectangle().fill(K.paperAlt.opacity(0.1)).frame(height: 1)
        }
    }

    private var emptyMap: some View {
        VStack(spacing: 10) {
            Text("Rien à cartographier")
                .font(KFont.display(21))
                .foregroundStyle(K.paperAlt)
            Text("Écris une page dans cette matière, et elle apparaîtra ici.")
                .font(KFont.body(13, weight: .bold))
                .foregroundStyle(K.paperAlt.opacity(0.55))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Le panneau de droite

    private var detailPanel: some View {
        Group {
            if let page = selectedPage, let node = layout.node(page.id) {
                pageDetail(page, node)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("LA CARTE")
                        .font(KFont.mono(10))
                        .tracking(1.2)
                        .foregroundStyle(K.inkSoft)
                    Text("Choisis un nœud pour voir ce qu'il contient.")
                        .font(KFont.body(13.5, weight: .bold))
                        .foregroundStyle(K.inkBody)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(24)
            }
        }
        // Pas de maxWidth ici : la largeur est fixee par l'appelant, et
        // l'etaler reprenait la place du graphe en paysage.
        .frame(maxHeight: .infinity)
        .background(K.paper)
    }

    private func pageDetail(_ page: Page, _ node: MemoryMap.Node) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Text(stateBadge(node.state))
                    .font(KFont.body(10.5, weight: .extraBold))
                    .tracking(0.9)
                    .foregroundStyle(K.ink)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .background(tint(node.state), in: Capsule())
                    .overlay(Capsule().strokeBorder(K.ink, lineWidth: 2.5))
                Text("\(page.writingSeconds / 60) MIN D'ÉCRITURE")
                    .font(KFont.mono(9.5))
                    .tracking(0.9)
                    .foregroundStyle(K.inkSoft)
                Spacer(minLength: 0)
            }

            DisplayText(page.title.isEmpty ? "Sans titre" : page.title, size: 26)
                .padding(.top, 12)

            Text(stateSentence(node.state))
                .font(KFont.body(12.5, weight: .bold))
                .foregroundStyle(K.inkBody)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)

            Text("CE QUE CETTE PAGE CONTIENT")
                .font(KFont.mono(9.5))
                .tracking(1.1)
                .foregroundStyle(K.inkSoft)
                .padding(.top, 20)

            VStack(spacing: 8) {
                // Une ligne « 0 carte capturée » n'apprend rien : la phrase
                // au-dessus l'a deja dit.
                if node.cardCount > 0 {
                    contentRow(K.brand, "\(node.cardCount) carte\(node.cardCount > 1 ? "s" : "") capturée\(node.cardCount > 1 ? "s" : "")",
                               trailing: dueCount(page) > 0 ? "\(dueCount(page)) dues" : nil)
                }
                if page.writingSeconds > 0 {
                    contentRow(K.reward, "Manuscrit · \(page.writingSeconds / 60) min", trailing: nil)
                }
                if !page.markdown.isEmpty {
                    contentRow(K.success, "Suite au markdown sur Mac", trailing: nil)
                }
                ForEach(page.assignments ?? []) { task in
                    contentRow(K.endangered, task.title, trailing: task.isDone ? "fait" : "à finir")
                }
            }
            .padding(.top, 10)

            Spacer(minLength: 20)

            if node.cardCount > 0 {
                Button { onReview((page.cards ?? []).map(\.id)) } label: {
                    HStack {
                        Text("RÉVISER CETTE PAGE")
                            .font(KFont.display(15))
                        Spacer(minLength: 8)
                        Text("\(node.cardCount) carte\(node.cardCount > 1 ? "s" : "")")
                            .font(KFont.body(12, weight: .extraBold))
                            .foregroundStyle(K.ink)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(K.paperAlt, in: Capsule())
                    }
                    .foregroundStyle(K.paperAlt)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity)
                    .sticker(fill: K.brand, radius: 16, state: .rest)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
    }

    private func contentRow(_ color: Color, _ label: String, trailing: String?) -> some View {
        HStack(spacing: 11) {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(color)
                .frame(width: 19, height: 19)
                .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(K.ink, lineWidth: 2.5))
            Text(label)
                .font(KFont.body(12.5, weight: .extraBold))
                .foregroundStyle(K.ink)
                .lineLimit(2)
            Spacer(minLength: 6)
            if let trailing {
                Text(trailing)
                    .font(KFont.mono(10))
                    .foregroundStyle(K.inkSoft)
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .background(K.paperAlt, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
            .strokeBorder(K.ink, lineWidth: 2.5))
    }

    // MARK: Donnees

    private var selectedCourse: Course? { courses.first { $0.id == selectedCourseID } }
    private var selectedPage: Page? { pages.first { $0.id == selectedPageID } }

    private var coursePages: [Page] {
        pages.filter { $0.course?.id == selectedCourseID && $0.course?.archivedAt == nil }
    }

    private var layout: MemoryMap.Layout {
        MemoryMap.layout(coursePages.map { page in
            .init(id: page.id, title: page.title, date: page.createdAt,
                  cards: (page.cards ?? []).map {
                      Freshness.CardState(dueAt: $0.dueAt, interval: $0.interval)
                  })
        })
    }

    /// Ce que Gribou pourrait dire devant la carte du semestre.
    private var mapTips: [GribouAdvice.Tip] {
        var tips: [GribouAdvice.Tip] = []
        let erased = layout.nodes.filter { $0.state == .endangered }
        let fading = layout.nodes.filter { $0.state == .toReview }

        if !erased.isEmpty {
            let titre = erased.first?.title ?? ""
            tips.append(.init(
                id: "carte.effacees",
                kind: .action,
                text: erased.count == 1
                    ? "« \(titre) » est presque effacée. C'est celle qui coûtera le plus cher à l'examen."
                    : "\(erased.count) nœuds sont presque effacés. Commence par « \(titre) » : c'est le plus ancien."))
        } else if fading.count >= 2 {
            tips.append(.init(
                id: "carte.palissent",
                kind: .debrief,
                text: "\(fading.count) nœuds commencent à pâlir. Une session les remet au vert."))
        }

        tips.append(.init(
            id: "carte.aretes",
            kind: .mechanic,
            text: "Les traits relient tes pages dans l'ordre où tu les as écrites. C'est ta progression réelle, pas un plan de cours."))

        if !layout.nodes.isEmpty, erased.isEmpty, fading.isEmpty {
            tips.append(.init(
                id: "carte.verte",
                kind: .cheer,
                text: "Toute la carte est verte. Rien ne s'efface en ce moment."))
        }
        return tips
    }

    private var mapMeta: String {
        let fading = layout.nodes.filter { $0.state == .toReview || $0.state == .endangered }.count
        let pages = layout.nodes.count
        var text = "\(pages) PAGE\(pages > 1 ? "S" : "") ÉCRITE\(pages > 1 ? "S" : "")"
        if fading > 0 { text += " · \(fading) QUI PÂLI\(fading > 1 ? "SSENT" : "T")" }
        return text
    }

    private func dueCount(_ page: Page) -> Int {
        (page.cards ?? []).filter { $0.dueAt <= .now }.count
    }

    private func selectFirstCourse() {
        guard selectedCourseID == nil else { return }
        selectedCourseID = courses.first { course in
            pages.contains { $0.course?.id == course.id }
        }?.id ?? courses.first?.id
        // La derniere page ecrite : un panneau vide au premier regard
        // n'apprend rien de la carte.
        selectedPageID = layout.nodes.last?.id
    }

    private func tint(_ state: Freshness.State) -> Color {
        switch state {
        case .acquired:   K.success
        case .toReview:   K.reward
        case .endangered: K.endangered
        case .draft:      K.paperAlt.opacity(0.25)
        }
    }

    private func stateBadge(_ state: Freshness.State) -> String {
        switch state {
        case .acquired:   "ENCRE FRAÎCHE"
        case .toReview:   "L'ENCRE PÂLIT"
        case .endangered: "PRESQUE EFFACÉE"
        case .draft:      "BROUILLON"
        }
    }

    private func stateSentence(_ state: Freshness.State) -> String {
        switch state {
        case .acquired:   "Cette page ne demande rien pour l'instant."
        case .toReview:   "Elle commence à pâlir. Une session la remettrait d'aplomb."
        case .endangered: "Presque effacée. C'est ici qu'on perd des points."
        case .draft:      "Aucune carte n'en est tirée : rien ne peut pâlir."
        }
    }
}
