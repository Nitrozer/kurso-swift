import SwiftUI
import SwiftData
import KursoCore
import KursoModels

/// Selection de la colonne de gauche.
enum CahierSelection: Hashable {
    case allPages
    case course(UUID)
}

/// Les « cahiers » : une matiere et ses pages en ordre chronologique.
///
/// Il n'existe volontairement pas d'entite `Notebook`. Le §12 refuse les dossiers
/// crees a la main — c'est l'emploi du temps qui range. Un cahier est donc une
/// `Course`, et les pages s'y rattachent seules a l'etape 2 via l'import ICS.
struct LibraryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Course.name) private var courses: [Course]
    @Query(sort: \Page.createdAt, order: .reverse) private var pages: [Page]

    @State private var selection: CahierSelection? = .allPages
    @State private var openedPageID: UUID?

    var body: some View {
        NavigationSplitView {
            sidebar
        } content: {
            pageList
        } detail: {
            if let page = openedPage {
                PageEditorView(page: page)
                    .id(page.id)
            } else {
                ContentUnavailableView(
                    "Aucune page ouverte",
                    systemImage: "doc.text",
                    description: Text("Choisissez une page, ou creez-en une.")
                )
            }
        }
    }

    // MARK: Colonne des cahiers

    private var sidebar: some View {
        List(selection: $selection) {
            Section {
                Label("Toutes les pages", systemImage: "tray.full")
                    .badge(pages.count)
                    .tag(CahierSelection.allPages)
            }
            Section("Matieres") {
                ForEach(courses) { course in
                    Label(course.name, systemImage: "book.closed")
                        .badge(pageCount(for: course))
                        .tag(CahierSelection.course(course.id))
                }
                if courses.isEmpty {
                    Text("Les matieres arriveront avec l'import de l'emploi du temps.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Kurso")
        #if os(iOS)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { addCourseButton } }
        #else
        .toolbar { ToolbarItem { addCourseButton } }
        #endif
    }

    /// Provisoire : a l'etape 2, les matieres viennent du fichier ICS et ce bouton
    /// disparait. Il n'existe ici que pour pouvoir eprouver le rangement par
    /// matiere avant que l'import existe.
    private var addCourseButton: some View {
        Button {
            let course = Course(name: "Matiere \(courses.count + 1)")
            context.insert(course)
            try? context.save()
        } label: {
            Label("Ajouter une matiere", systemImage: "plus")
        }
    }

    // MARK: Colonne des pages datees

    private var pageList: some View {
        List(selection: $openedPageID) {
            ForEach(days, id: \.start) { day in
                Section(day.start.formatted(.dateTime.weekday(.wide).day().month(.wide))) {
                    ForEach(day.items) { page in
                        pageRow(page).tag(page.id)
                    }
                    .onDelete { offsets in delete(offsets, in: day.items) }
                }
            }
            if visiblePages.isEmpty {
                ContentUnavailableView(
                    "Aucune page",
                    systemImage: "doc",
                    description: Text("Creez la premiere page de ce cahier.")
                )
            }
        }
        .navigationTitle(selectionTitle)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { newPageButton } }
        #else
        .toolbar { ToolbarItem { newPageButton } }
        #endif
    }

    private func pageRow(_ page: Page) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(page.title.isEmpty ? "Page sans titre" : page.title)
                .lineLimit(1)
            HStack(spacing: 6) {
                Text(page.createdAt, format: .dateTime.hour().minute())
                if page.writingSeconds >= 60 {
                    Text("· \(page.writingSeconds / 60) min")
                }
                if page.drawing == nil {
                    Text("· vide").foregroundStyle(.tertiary)
                }
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
    }

    private var newPageButton: some View {
        Button {
            let page = Page(createdAt: .now)
            page.course = selectedCourse
            context.insert(page)
            try? context.save()
            openedPageID = page.id
        } label: {
            Label("Nouvelle page", systemImage: "square.and.pencil")
        }
    }

    // MARK: Donnees derivees

    private var selectedCourse: Course? {
        guard case .course(let id) = selection else { return nil }
        return courses.first { $0.id == id }
    }

    private var selectionTitle: String {
        selectedCourse?.name ?? "Toutes les pages"
    }

    private var visiblePages: [Page] {
        guard let course = selectedCourse else { return pages }
        return pages.filter { $0.course?.id == course.id }
    }

    private var days: [DayGrouping.Day<Page>] {
        DayGrouping.byDay(visiblePages) { $0.createdAt }
    }

    private var openedPage: Page? {
        pages.first { $0.id == openedPageID }
    }

    private func pageCount(for course: Course) -> Int {
        pages.filter { $0.course?.id == course.id }.count
    }

    private func delete(_ offsets: IndexSet, in group: [Page]) {
        for index in offsets {
            let page = group[index]
            if page.id == openedPageID { openedPageID = nil }
            context.delete(page)
        }
        try? context.save()
    }
}
