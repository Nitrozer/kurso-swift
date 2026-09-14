import SwiftUI
import KursoCore
import KursoModels

/// La planche des cahiers.
///
/// L'emploi du temps en fabrique un par matiere (§6) — on n'en cree pas a la
/// main, le §12 l'interdit. En revanche on les personnalise : un nom et une
/// couleur, de quoi retrouver le sien d'un coup d'oeil.
struct CahiersGrid: View {
    let courses: [Course]
    /// Nombre de pages par cahier, matiere par matiere.
    var pageCount: (Course) -> Int
    /// Les pages qui n'appartiennent a aucune matiere.
    var looseCount: Int
    var onOpen: (Course?) -> Void
    var onCustomise: (Course) -> Void

    private let columns = [GridItem(.adaptive(minimum: 210), spacing: 16)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(courses) { course in
                    card(course)
                }
                if looseCount > 0 { looseCard }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
    }

    private func card(_ course: Course) -> some View {
        let color = K.cahier(CourseColor.named(course.colorToken))
        return Button { onOpen(course) } label: {
            VStack(alignment: .leading, spacing: 0) {
                // La tranche coloree, comme un vrai cahier pose de profil.
                CahierCover(color: color, cover: Shop.Cover.named(course.coverStyle))
                    .frame(height: 82)

                VStack(alignment: .leading, spacing: 3) {
                    Text(course.name)
                        .font(KFont.body(14, weight: .extraBold))
                        .foregroundStyle(K.ink)
                        .lineLimit(2)
                    MetaText(label(pageCount(course)), size: 9.5)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 13)
                .padding(.vertical, 11)
            }
            .background(K.paperAlt)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(K.ink, lineWidth: 3))
            .background(alignment: .top) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(K.ink).offset(y: 4)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Personnaliser") { onCustomise(course) }
        }
    }

    private var looseCard: some View {
        Button { onOpen(nil) } label: {
            VStack(alignment: .leading, spacing: 0) {
                ZStack {
                    K.paper
                    Text("?")
                        .font(KFont.display(30))
                        .foregroundStyle(K.ink.opacity(0.35))
                }
                .frame(height: 82)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Sans matière")
                        .font(KFont.body(14, weight: .extraBold))
                        .foregroundStyle(K.ink)
                    MetaText(label(looseCount), size: 9.5)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 13).padding(.vertical, 11)
            }
            .background(K.paperAlt)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(K.ink.opacity(0.35), style: StrokeStyle(lineWidth: 3, dash: [7, 5])))
        }
        .buttonStyle(.plain)
    }

    private func label(_ count: Int) -> String {
        count == 0 ? "CAHIER VIDE" : "\(count) PAGE\(count > 1 ? "S" : "")"
    }
}

/// Personnalisation d'un cahier : son nom et sa couleur.
struct CahierSettings: View {
    @Bindable var course: Course
    var onDone: () -> Void

    @Environment(\.modelContext) private var context
    @State private var shavings = 0
    @State private var owned: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                MetaText("Cahier")
                DisplayText("Personnaliser", size: 26)
            }

            TextField("Nom du cahier", text: $course.name)
                .textFieldStyle(.plain)
                .font(KFont.body(15, weight: .extraBold))
                .foregroundStyle(K.ink)
                .padding(14)
                .sticker(fill: K.paperAlt, radius: 14, state: .done)

            VStack(alignment: .leading, spacing: 9) {
                MetaText("Couleur")
                HStack(spacing: 11) {
                    ForEach(CourseColor.allCases, id: \.self) { color in
                        Button { course.colorToken = color.token } label: {
                            Circle()
                                .fill(K.cahier(color))
                                .frame(width: 38, height: 38)
                                .overlay(Circle().strokeBorder(
                                    K.ink,
                                    lineWidth: course.colorToken == color.token ? 4 : 2))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(color.label)
                    }
                }
            }

            covers

            Button("Terminer") { onDone() }
                .buttonStyle(StickerButtonStyle(kind: .primary))
        }
        .padding(26)
        .frame(maxWidth: 520)
        .background(K.paper)
        .task { refreshPlayer() }
    }

    /// Les couvertures. Elles n'achetent que de l'apparence : aucune ne donne
    /// d'avance, le §12 l'interdit.
    private var covers: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                MetaText("Couverture")
                Spacer()
                Text("\(shavings) copeaux")
                    .font(KFont.mono(10))
                    .foregroundStyle(K.inkSoft)
            }
            HStack(spacing: 10) {
                ForEach(Shop.Cover.allCases, id: \.self) { cover in
                    coverChip(cover)
                }
            }
        }
    }

    private func coverChip(_ cover: Shop.Cover) -> some View {
        let isOwned = Shop.isOwned(cover, owned: owned)
        let isCurrent = course.coverStyle == cover.rawValue
        return Button {
            if isOwned {
                course.coverStyle = cover.rawValue
                try? context.save()
            } else {
                buy(cover)
            }
        } label: {
            VStack(spacing: 4) {
                CahierCover(color: K.cahier(CourseColor.named(course.colorToken)), cover: cover)
                    .frame(width: 54, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(isCurrent ? K.brand : K.ink.opacity(0.3),
                                      lineWidth: isCurrent ? 3 : 1.5))
                    .opacity(isOwned ? 1 : 0.45)
                Text(isOwned ? cover.label : "\(cover.price)")
                    .font(KFont.mono(9))
                    .foregroundStyle(isOwned ? K.inkSoft
                                     : (shavings >= cover.price ? K.brand : K.inkSoft.opacity(0.6)))
            }
        }
        .buttonStyle(.plain)
        .disabled(!isOwned && shavings < cover.price)
    }

    private func buy(_ cover: Shop.Cover) {
        let player = PlayerStore.current(context)
        guard let left = Shop.buy(cover, shavings: player.shavings, owned: owned) else { return }
        player.shavings = left
        player.ownedCovers.append(cover.rawValue)
        course.coverStyle = cover.rawValue
        try? context.save()
        refreshPlayer()
    }

    private func refreshPlayer() {
        let player = PlayerStore.current(context)
        shavings = player.shavings
        owned = Set(player.ownedCovers)
    }
}
