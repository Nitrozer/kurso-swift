import SwiftUI
import SwiftData
import KursoCore
import KursoModels

/// La liste des signets poses en cours.
///
/// C'est l'autre moitie du geste : marquer ne sert a rien si l'on ne retrouve
/// pas les marques. On les range par jour, parce qu'on y revient le soir meme
/// ou le week-end — « ce qu'il a dit jeudi », pas « page 14 ».
struct BookmarksView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \PageBookmark.createdAt, order: .reverse) private var marks: [PageBookmark]

    /// Ouvre la page a la hauteur marquee.
    var onOpen: (Page, Double) -> Void
    var onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                DisplayText("Signets", size: 24)
                Spacer(minLength: 0)
                Button("Fermer", action: onClose)
                    .buttonStyle(.plain)
                    .font(KFont.body(12.5, weight: .extraBold))
                    .foregroundStyle(K.inkSoft)
            }

            if marks.isEmpty {
                Text("Rien de marqué. Pendant un cours, le ruban au bord droit de la page pose un signet là où tu regardes — un appui, sans rien écrire.")
                    .font(KFont.body(13, weight: .bold))
                    .foregroundStyle(K.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(groups, id: \.day) { group in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(Bookmarks.day(group.day).uppercased())
                                    .font(KFont.body(10, weight: .extraBold))
                                    .tracking(1.2)
                                    .foregroundStyle(K.inkSoft)
                                ForEach(group.items, id: \.id) { mark in
                                    row(mark)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 8)
                }
                .scrollIndicators(.hidden)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(K.paper)
    }

    private var groups: [(day: Date, items: [PageBookmark])] {
        Bookmarks.grouped(marks, date: \.createdAt)
    }

    private func row(_ mark: PageBookmark) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // L'onglet, comme au bord de la page : on reconnait la marque.
            UnevenRoundedRectangle(topLeadingRadius: 4, bottomLeadingRadius: 4,
                                   bottomTrailingRadius: 4, topTrailingRadius: 4,
                                   style: .continuous)
                .fill(tint(mark))
                .overlay(UnevenRoundedRectangle(topLeadingRadius: 4, bottomLeadingRadius: 4,
                                                bottomTrailingRadius: 4, topTrailingRadius: 4,
                                                style: .continuous)
                    .strokeBorder(K.ink, lineWidth: 2))
                .frame(width: 14, height: 22)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Button { open(mark) } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title(mark))
                            .font(KFont.body(13.5, weight: .extraBold))
                            .foregroundStyle(K.ink)
                            .lineLimit(1)
                        Text(subtitle(mark))
                            .font(KFont.mono(9.5))
                            .foregroundStyle(K.inkSoft)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                // Le commentaire s'ecrit ici, pas en cours : en amphi on n'a
                // pas le temps, le soir on a le contexte.
                TextField("Ajouter un mot…", text: Binding(
                    get: { mark.note },
                    set: { mark.note = $0; try? context.save() }
                ))
                .textFieldStyle(.plain)
                .font(KFont.body(12, weight: .bold))
                .foregroundStyle(K.ink)
            }

            Button { remove(mark) } label: {
                CrossGlyph()
                    .stroke(K.inkSoft, style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                    .frame(width: 10, height: 10)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Retirer ce signet")
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(K.paperAlt, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(K.ink.opacity(0.18), lineWidth: 1.5))
    }

    private func title(_ mark: PageBookmark) -> String {
        guard let page = mark.page else { return "Page supprimée" }
        let name = page.title.trimmingCharacters(in: .whitespaces)
        if !name.isEmpty { return name }
        let excerpt = Bookmarks.excerpt(from: page.recognizedText.isEmpty ? page.slideText
                                                                          : page.recognizedText)
        return excerpt.isEmpty ? "Page sans titre" : excerpt
    }

    private func subtitle(_ mark: PageBookmark) -> String {
        let hour = mark.createdAt.formatted(.dateTime.hour().minute())
        guard let course = mark.page?.course else { return hour }
        return "\(hour) · \(course.name)"
    }

    private func tint(_ mark: PageBookmark) -> Color {
        guard let token = mark.page?.course?.colorToken else { return K.reward }
        return K.cahier(CourseColor.named(token))
    }

    private func open(_ mark: PageBookmark) {
        guard let page = mark.page else { return }
        onOpen(page, mark.height)
    }

    private func remove(_ mark: PageBookmark) {
        context.delete(mark)
        try? context.save()
    }
}
