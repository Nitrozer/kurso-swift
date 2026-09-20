#if os(iOS)
import SwiftUI
import SwiftData
import KursoCore
import KursoModels

/// Choisir la page a lire a cote.
///
/// On montre les vraies pages, pas une liste de titres : une page de cours se
/// reconnait a son allure bien avant son titre, et beaucoup n'en ont pas.
struct SidePagePicker: View {
    /// La matiere ouverte : c'est presque toujours la-dedans qu'on cherche.
    let preferred: Course?
    /// La page qu'on est en train d'ecrire ne se propose pas a cote d'elle.
    let excluding: UUID
    var onPick: (Page) -> Void
    var onCancel: () -> Void

    @Query(sort: \Course.name) private var courses: [Course]
    @State private var chosen: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                DisplayText("Ouvrir à côté", size: 24)
                Spacer(minLength: 0)
                Button("Annuler", action: onCancel)
                    .buttonStyle(.plain)
                    .font(KFont.body(12.5, weight: .extraBold))
                    .foregroundStyle(K.inkSoft)
            }

            if available.isEmpty {
                Text("Aucune autre page à lire pour l'instant.")
                    .font(KFont.body(13, weight: .bold))
                    .foregroundStyle(K.inkSoft)
            } else {
                WrapLayout(spacing: 7, lineSpacing: 7) {
                    ForEach(available, id: \.id) { course in
                        chip(course)
                    }
                }

                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 116), spacing: 14)], spacing: 14) {
                        ForEach(pages, id: \.id) { page in
                            Button { onPick(page) } label: {
                                VStack(spacing: 5) {
                                    PagePreview(page: page, renderWidth: 220)
                                        .frame(width: 116, height: 158)
                                        .background(K.paperAlt)
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .strokeBorder(K.ink.opacity(0.22), lineWidth: 1.5))
                                    Text(page.title.isEmpty ? "Sans titre" : page.title)
                                        .font(KFont.body(10.5, weight: .bold))
                                        .foregroundStyle(K.inkBody)
                                        .lineLimit(1)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(K.paper)
        .onAppear { chosen = chosen ?? preferred?.id ?? available.first?.id }
    }

    /// Les cahiers qui ont autre chose a lire que la page ouverte.
    private var available: [Course] {
        courses.filter { course in
            course.archivedAt == nil && (course.pages ?? []).contains { $0.id != excluding }
        }
    }

    private var pages: [Page] {
        guard let chosen, let course = available.first(where: { $0.id == chosen }) else { return [] }
        return (course.pages ?? [])
            .filter { $0.id != excluding }
            .sorted { $0.position < $1.position }
    }

    private func chip(_ course: Course) -> some View {
        let isOn = chosen == course.id
        return Button { chosen = course.id } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(K.cahier(CourseColor.named(course.colorToken)))
                    .frame(width: 8, height: 8)
                Text(course.name)
                    .font(KFont.body(11.5, weight: .extraBold))
                    .foregroundStyle(isOn ? K.paperAlt : K.ink)
            }
            .padding(.vertical, 7).padding(.horizontal, 12)
            .background(isOn ? K.ink : .clear, in: Capsule())
            .overlay(Capsule().strokeBorder(isOn ? .clear : K.ink.opacity(0.2), lineWidth: 1.5))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
#endif
