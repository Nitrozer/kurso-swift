import SwiftUI
import SwiftData
import KursoCore
import KursoModels

/// La semaine : ce qui attend l'étudiant, pas seulement aujourd'hui.
///
/// C'est la question du dimanche soir — celle où l'on décide quand réviser.
/// L'écran du jour, lui, répond à « maintenant ».
struct WeekView: View {
    var onClose: () -> Void

    @Query private var slots: [TimeSlot]
    @Query private var assignments: [Assignment]
    @Query private var seasons: [Season]

    @State private var anchor = Date()
    private let calendar = Calendar.current

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if days.isEmpty {
                EmptyState(title: "Pas de semaine à montrer")
            } else {
                grid
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(K.paper)
    }

    // MARK: En-tête

    private var header: some View {
        HStack(spacing: 12) {
            Button(action: onClose) {
                ChevronGlyph()
                    .stroke(K.ink, style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
                    .frame(width: 12, height: 12)
                    .frame(width: 34, height: 34)
                    .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(K.ink, lineWidth: 2.5))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Fermer")

            DisplayText(WeekPlan.title(days, calendar: calendar), size: 26)

            step(-1, label: "Semaine précédente")
            step(1, label: "Semaine suivante")

            if !isThisWeek {
                Button("Cette semaine") { anchor = Date() }
                    .buttonStyle(.plain)
                    .font(KFont.body(11.5, weight: .extraBold))
                    .foregroundStyle(K.brand)
            }
            Spacer(minLength: 0)
            Text(hours.lowerBound == 8 && weekSlots.isEmpty ? "" : "\(weekSlots.count) cours")
                .font(KFont.mono(11))
                .foregroundStyle(K.inkSoft)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
    }

    private func step(_ by: Int, label: String) -> some View {
        Button {
            anchor = calendar.date(byAdding: .day, value: by * 7, to: anchor) ?? anchor
        } label: {
            ChevronGlyph(pointsRight: by > 0)
                .stroke(K.ink, style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                .frame(width: 10, height: 10)
                .frame(width: 30, height: 30)
                .overlay(Circle().strokeBorder(K.ink.opacity(0.2), lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: La grille

    /// Une heure vaut toujours la meme hauteur, et la grille defile.
    ///
    /// Comprimer la journee entiere dans la hauteur de l'ecran ecrasait les
    /// cours en bandes de quelques points des qu'une semaine s'etalait — et
    /// une seance nocturne suffisait a rendre toutes les autres illisibles.
    private static let hourHeight: CGFloat = 56

    private var totalHeight: CGFloat {
        CGFloat(hours.upperBound - hours.lowerBound) * Self.hourHeight
    }

    private var grid: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                // Une hauteur explicite : sans elle, cette cale vide s'etire
                // et repousse toute la grille vers le bas.
                Color.clear.frame(width: 44, height: 1)
                ForEach(days, id: \.self) { day in
                    dayHeader(day)
                }
            }
            .padding(.trailing, 24)

            ScrollViewReader { reader in
                ScrollView {
                    HStack(alignment: .top, spacing: 0) {
                        hoursColumn(height: totalHeight)
                        ForEach(days, id: \.self) { day in
                            column(day, height: totalHeight)
                        }
                    }
                    .frame(height: totalHeight)
                    .padding(.trailing, 24)
                    .padding(.bottom, 12)
                }
                .scrollIndicators(.hidden)
                // On arrive sur le premier cours, pas a minuit. Une seance
                // nocturne ouvrirait sinon la grille sur huit heures de vide.
                .onAppear {
                    // Un instant d'attente : au tout premier affichage la grille
                    // n'a pas encore sa hauteur, et le defilement partirait dans
                    // le vide.
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(80))
                        reader.scrollTo(openingHour, anchor: .top)
                    }
                }
                .onChange(of: anchor) { _, _ in
                    reader.scrollTo(openingHour, anchor: .top)
                }
            }
        }
        .padding(.leading, 24)
        .padding(.bottom, 20)
    }

    private func dayHeader(_ day: Date) -> some View {
        let today = calendar.isDateInToday(day)
        return VStack(spacing: 5) {
            Text("\(WeekPlan.shortName(day, calendar: calendar)) \(calendar.component(.day, from: day))")
                .font(KFont.body(11.5, weight: .extraBold))
                .foregroundStyle(today ? K.paperAlt : K.ink)
                .padding(.vertical, 5).padding(.horizontal, 10)
                .background(today ? K.ink : .clear, in: Capsule())

            // Les rendus et les partiels du jour : c'est pour eux qu'on
            // regarde la semaine.
            ForEach(marks(on: day), id: \.id) { mark in
                Text(mark.label)
                    .font(KFont.body(9.5, weight: .extraBold))
                    .foregroundStyle(K.ink)
                    .lineLimit(1)
                    .padding(.vertical, 3).padding(.horizontal, 6)
                    .frame(maxWidth: .infinity)
                    .background(mark.tint, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 3)
        .padding(.bottom, 8)
    }

    /// Une pile de rangs plutot qu'un empilement decale : un .offset ne
    /// deplace que le rendu, et le defilement automatique a besoin de
    /// positions reelles pour viser une heure.
    private func hoursColumn(height: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(hours.lowerBound..<hours.upperBound, id: \.self) { hour in
                Text("\(hour) h")
                    .font(KFont.mono(9.5))
                    .foregroundStyle(K.inkSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: Self.hourHeight, alignment: .top)
                    .offset(y: -6)
                    .id(hour)
            }
        }
        .frame(width: 44, height: height, alignment: .topLeading)
        // La derniere heure ne commence aucun rang : elle ferme la grille.
        .overlay(alignment: .bottomLeading) {
            Text("\(hours.upperBound) h")
                .font(KFont.mono(9.5))
                .foregroundStyle(K.inkSoft)
                .offset(y: -6)
        }
    }

    private func column(_ day: Date, height: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            // Les traits d'heure, derriere.
            ForEach(Array(hours), id: \.self) { hour in
                Rectangle()
                    .fill(K.ink.opacity(0.07))
                    .frame(height: 1)
                    .offset(y: offset(of: hour, in: height))
            }
            ForEach(slots(on: day), id: \.id) { slot in
                block(slot, height: height)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: height, alignment: .topLeading)
        .background(calendar.isDateInToday(day) ? K.reward.opacity(0.10) : .clear)
        .padding(.horizontal, 3)
    }

    private func block(_ slot: TimeSlot, height: CGFloat) -> some View {
        let place = WeekPlan.placement((start: slot.start, end: slot.end),
                                       in: hours, calendar: calendar)
        let tint = slot.course.map { K.cahier(CourseColor.named($0.colorToken)) } ?? K.inkSoft
        return VStack(alignment: .leading, spacing: 1) {
            Text(slot.course?.name ?? slot.summary)
                .font(KFont.body(10.5, weight: .extraBold))
                .foregroundStyle(K.paperAlt)
                .lineLimit(2)
            if let room = slot.location {
                Text(room)
                    .font(KFont.mono(8.5))
                    .foregroundStyle(K.paperAlt.opacity(0.8))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: max(height * place.height, 18), alignment: .topLeading)
        .background(tint, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .offset(y: height * place.y)
    }

    // MARK: Données

    private var days: [Date] { WeekPlan.days(containing: anchor, calendar: calendar) }

    private var isThisWeek: Bool {
        days.contains { calendar.isDateInToday($0) }
    }

    private var weekSlots: [TimeSlot] {
        guard let first = days.first, let last = days.last,
              let end = calendar.date(byAdding: .day, value: 1, to: last) else { return [] }
        return slots.filter { $0.start >= first && $0.start < end }
    }

    /// Les heures se calculent sur TOUTE la semaine, pas jour par jour :
    /// sinon chaque colonne aurait sa propre echelle et rien ne s'alignerait.
    private var hours: ClosedRange<Int> {
        WeekPlan.hours(for: weekSlots.map { (start: $0.start, end: $0.end) }, calendar: calendar)
    }

    private func slots(on day: Date) -> [TimeSlot] {
        weekSlots.filter { calendar.isDate($0.start, inSameDayAs: day) }
            .sorted { $0.start < $1.start }
    }

    /// L'heure sur laquelle la grille s'ouvre : le premier cours du jour si
    /// la semaine contient aujourd'hui, sinon le premier de la semaine.
    private var openingHour: Int {
        let mine = days.first { calendar.isDateInToday($0) }.map { slots(on: $0) } ?? []
        let reference = mine.isEmpty ? weekSlots.sorted { $0.start < $1.start } : mine
        guard let first = reference.first else { return hours.lowerBound }
        return max(hours.lowerBound, calendar.component(.hour, from: first.start) - 1)
    }

    private func offset(of hour: Int, in height: CGFloat) -> CGFloat {
        let span = CGFloat(hours.upperBound - hours.lowerBound)
        guard span > 0 else { return 0 }
        return height * CGFloat(hour - hours.lowerBound) / span
    }

    private struct Mark: Identifiable {
        let id: UUID
        let label: String
        let tint: Color
    }

    /// Rendus et partiels du jour.
    private func marks(on day: Date) -> [Mark] {
        var found: [Mark] = []
        for task in assignments where !task.isDone && !task.wasProposed {
            if let due = task.dueAt, calendar.isDate(due, inSameDayAs: day) {
                found.append(Mark(id: task.id, label: task.title, tint: K.reward))
            }
        }
        for season in seasons {
            if let exam = season.examDate, calendar.isDate(exam, inSameDayAs: day) {
                found.append(Mark(id: season.id, label: "Partiel", tint: K.alertOnDark))
            }
        }
        return found
    }
}
