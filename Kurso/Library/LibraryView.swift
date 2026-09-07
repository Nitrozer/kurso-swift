import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import KursoCore
import KursoModels

enum CahierSelection: Hashable {
    case allPages
    case course(UUID)
}

/// Les cahiers : les pages d'une matiere, en ordre chronologique.
///
/// Il n'existe pas d'entite `Notebook` : les dossiers crees a la main sont
/// refuses, c'est l'emploi du temps qui range.
struct LibraryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Course.name) private var courses: [Course]
    @Query(sort: \Page.createdAt, order: .reverse) private var pages: [Page]

    @State private var selection: CahierSelection = .allPages
    @State private var openedPage: Page?
    @State private var query = ""
    @State private var isImporting = false
    @State private var isPickingPDF = false
    @FocusState private var isSearching: Bool

    var body: some View {
        if let page = openedPage {
            PageEditorView(page: page, onClose: { openedPage = nil })
                .id(page.id)
        } else {
            library
        }
    }

    private var library: some View {
        VStack(spacing: 0) {
            header
            courseFilter
            if courses.isEmpty { importInvite }
            grid
        }
        .sheet(isPresented: $isImporting) {
            TimetableOnboardingView()
        }
        .fileImporter(isPresented: $isPickingPDF, allowedContentTypes: [.pdf]) { result in
            guard case .success(let url) = result else { return }
            let pages = try? PDFImporter.importFile(at: url, course: selectedCourse, context: context)
            openedPage = pages?.first
        }
    }

    /// Tant qu'aucun emploi du temps n'est importe, les pages ne peuvent pas se
    /// ranger seules — c'est l'emploi du temps qui range (§12).
    private var importInvite: some View {
        Button { isImporting = true } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Importe ton emploi du temps")
                        .font(KFont.body(13.5, weight: .extraBold))
                        .foregroundStyle(K.ink)
                    Text("Tes pages se rangeront seules dans la bonne matiere.")
                        .font(KFont.body(12, weight: .bold))
                        .foregroundStyle(K.inkBody)
                }
                Spacer(minLength: 0)
                ChevronGlyph(pointsRight: true)
                    .stroke(K.ink, style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
                    .frame(width: 12, height: 12)
            }
            .padding(16)
            .sticker(fill: K.reward, radius: 16)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 28)
        .padding(.top, 16)
    }

    // MARK: En-tete

    private var header: some View {
        HStack(alignment: .bottom, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                MetaText(headerMeta, size: 10.5)
                DisplayText("Mes pages", size: 30)
            }
            Spacer(minLength: 0)
            searchField
            newPageButton
        }
        .padding(.horizontal, 28)
        .padding(.top, 22)
        .padding(.bottom, 16)
        .overlay(alignment: .bottom) {
            Rectangle().fill(K.ink.opacity(0.1)).frame(height: 1)
        }
    }

    private var headerMeta: String {
        let name = selectedCourse?.name ?? "Toutes les matieres"
        return "\(name) · \(visiblePages.count) pages"
    }

    /// « Chercher dans l'ecriture » : la requete porte sur le texte reconnu,
    /// jamais sur une reecriture des notes.
    private var searchField: some View {
        HStack(spacing: 8) {
            Glyph(kind: .search, size: 14, color: K.inkSoft)
            TextField("Chercher dans l'ecriture", text: $query)
                .textFieldStyle(.plain)
                .font(KFont.body(12, weight: .bold))
                .foregroundStyle(K.ink)
                .focused($isSearching)
                .frame(width: 190)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Glyph(kind: .plus, size: 11, color: K.inkSoft)
                        .rotationEffect(.degrees(45))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Effacer la recherche")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .overlay(Capsule().strokeBorder(K.ink, lineWidth: 2.5))
    }

    private var newPageButton: some View {
        Button {
            let page = Page(createdAt: .now)
            context.insert(page)
            // Le creneau en cours prime sur le filtre affiche : c'est l'emploi
            // du temps qui range, pas la colonne qu'on regardait (§12).
            if PageAttachment.attach(page, context: context) == nil {
                page.course = selectedCourse
            }
            try? context.save()
            openedPage = page
        } label: {
            HStack(spacing: 8) {
                Glyph(kind: .plus, size: 14, color: K.paperAlt)
                Text("Nouvelle page")
                    .font(KFont.body(12.5, weight: .extraBold))
                    .foregroundStyle(K.paperAlt)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 8)
            .background(K.brand, in: Capsule())
            .overlay(Capsule().strokeBorder(K.ink, lineWidth: 3))
            .background(alignment: .top) { Capsule().fill(K.ink).offset(y: 3) }
        }
        .buttonStyle(.plain)
    }

    // MARK: Filtre par matiere

    @ViewBuilder private var courseFilter: some View {
        if !courses.isEmpty {
            ScrollView(.horizontal) {
                HStack(spacing: 9) {
                    chip("Toutes", isActive: selection == .allPages) { selection = .allPages }
                    ForEach(courses) { course in
                        chip(course.name, isActive: selection == .course(course.id)) {
                            selection = .course(course.id)
                        }
                    }
                    importButton
                    pdfButton
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func chip(_ label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(KFont.body(12, weight: .extraBold))
                .foregroundStyle(isActive ? K.paperAlt : K.ink)
                .padding(.horizontal, 13)
                .padding(.vertical, 7)
                .background(isActive ? K.ink : .clear, in: Capsule())
                .overlay(Capsule().strokeBorder(K.ink, lineWidth: 2.5))
        }
        .buttonStyle(.plain)
    }

    /// Depot d'un polycopie : une page Kurso par diapo.
    private var pdfButton: some View {
        Button { isPickingPDF = true } label: {
            HStack(spacing: 7) {
                Glyph(kind: .plus, size: 12)
                Text("Deposer un PDF")
                    .font(KFont.body(12, weight: .extraBold))
                    .foregroundStyle(K.ink)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .overlay(Capsule().strokeBorder(K.ink, lineWidth: 2.5))
        }
        .buttonStyle(.plain)
    }

    /// Ouvre l'import d'emploi du temps : c'est lui qui cree les matieres.
    private var importButton: some View {
        Button { isImporting = true } label: {
            HStack(spacing: 7) {
                Glyph(kind: .plus, size: 12)
                Text("Emploi du temps")
                    .font(KFont.body(12, weight: .extraBold))
                    .foregroundStyle(K.ink)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .overlay(Capsule().strokeBorder(K.ink, lineWidth: 2.5))
        }
        .buttonStyle(.plain)
    }

    // MARK: Grille de pages

    @ViewBuilder private var grid: some View {
        if !query.isEmpty {
            searchResults
        } else if visiblePages.isEmpty {
            EmptyState(title: "Aucune page", message: "Creez la premiere page de ce cahier.")
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    ForEach(days, id: \.start) { day in
                        VStack(alignment: .leading, spacing: 11) {
                            MetaText(day.start.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                                .padding(.horizontal, 28)
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(day.items) { page in
                                    PageCard(page: page) { openedPage = page }
                                }
                            }
                            .padding(.horizontal, 28)
                        }
                    }
                }
                .padding(.vertical, 20)
            }
            .scrollIndicators(.hidden)
        }
    }

    @ViewBuilder private var searchResults: some View {
        let hits = TextSearch.rank(visiblePages, query: query) { $0.recognizedText }
        if hits.isEmpty {
            EmptyState(
                title: "Rien trouve",
                message: "Aucune page ne contient « \(query) ». La recherche porte sur l'ecriture reconnue."
            )
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 11) {
                    MetaText("\(hits.count) resultats")
                        .padding(.horizontal, 28)
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(hits, id: \.item.id) { hit in
                            PageCard(page: hit.item) { openedPage = hit.item }
                        }
                    }
                    .padding(.horizontal, 28)
                }
                .padding(.vertical, 20)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.adaptive(minimum: 168, maximum: 260), spacing: 16), count: 1)
    }

    // MARK: Donnees derivees

    private var selectedCourse: Course? {
        guard case .course(let id) = selection else { return nil }
        return courses.first { $0.id == id }
    }

    private var visiblePages: [Page] {
        guard let course = selectedCourse else { return pages }
        return pages.filter { $0.course?.id == course.id }
    }

    private var days: [DayGrouping.Day<Page>] {
        DayGrouping.byDay(visiblePages) { $0.createdAt }
    }
}
