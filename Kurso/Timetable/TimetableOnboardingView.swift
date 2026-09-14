import SwiftUI
import SwiftData
import KursoCore
import KursoModels

/// Import de l'emploi du temps, en deux temps : coller le lien, puis valider
/// les matières détectées (§6, ecran 03).
///
/// Rien n'est cree avant la validation : le regroupement est une proposition,
/// jamais une decision prise a la place de l'etudiant.
struct TimetableOnboardingView: View {
    /// Fourni pendant l'onboarding : l'ecran enchaine au lieu de se fermer.
    var onFinish: (() -> Void)?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \TimeSlot.start) private var slots: [TimeSlot]
    @Query(sort: \Course.name) private var courses: [Course]
    @Query private var timetables: [Timetable]

    @State private var isReplacing = false
    @State private var url = ""
    @State private var proposals: [TimetableImporter.Proposal] = []
    @State private var events: [ICSEvent] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            // Un emploi du temps deja importe se consulte : proposer d'en
            // ajouter un second n'a pas de sens.
            if hasTimetable && !isReplacing {
                currentStep
            } else if proposals.isEmpty {
                urlStep
            } else {
                reviewStep
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(K.paper)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            MetaText(headerMeta)
            DisplayText(headerTitle, size: 30)
        }
        .padding(.horizontal, 28)
        .padding(.top, 26)
        .padding(.bottom, 18)
    }

    private func close() {
        if let onFinish { onFinish() } else { dismiss() }
    }

    private var hasTimetable: Bool { !slots.isEmpty }

    private var headerMeta: String {
        if hasTimetable && !isReplacing { return "Emploi du temps" }
        return proposals.isEmpty ? "Étape 1 sur 2" : "Étape 2 sur 2"
    }

    private var headerTitle: String {
        if hasTimetable && !isReplacing { return "Ton emploi du temps" }
        return proposals.isEmpty ? "Ton emploi du temps" : "\(proposals.count) matières détectées"
    }

    // MARK: L'emploi du temps deja en place

    private var currentStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text(summaryLine)
                        .font(KFont.body(13.5, weight: .bold))
                        .foregroundStyle(K.ink.opacity(0.75))

                    ForEach(courses) { course in
                        courseRow(course)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)

            HStack(spacing: 12) {
                Button("Fermer") { try? context.save(); close() }
                    .buttonStyle(StickerButtonStyle(kind: .secondary))
                Button("Remplacer") {
                    url = timetables.first?.url ?? ""
                    isReplacing = true
                }
                .buttonStyle(StickerButtonStyle(kind: .primary))
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 22)
        }
    }

    /// Un intitule d'ENT se corrige apres coup : « CM ALGO S3 » n'est pas un
    /// nom de matiere, et on ne s'en apercoit souvent qu'a l'usage.
    @ViewBuilder private func courseRow(_ course: Course) -> some View {
        @Bindable var bound = course
        HStack(spacing: 13) {
            Menu {
                ForEach(CourseColor.allCases, id: \.self) { color in
                    Button(color.label) { bound.colorToken = color.token }
                }
            } label: {
                Circle()
                    .fill(K.cahier(CourseColor.named(course.colorToken)))
                    .frame(width: 22, height: 22)
                    .overlay(Circle().strokeBorder(K.ink, lineWidth: 2.5))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            VStack(alignment: .leading, spacing: 3) {
                TextField("Nom de la matière", text: $bound.name)
                    .textFieldStyle(.plain)
                    .font(KFont.body(14, weight: .extraBold))
                    .foregroundStyle(K.ink)
                    .onSubmit { try? context.save() }
                MetaText(courseSubtitle(course))
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sticker(fill: K.paperAlt, radius: 14)
    }

    private var summaryLine: String {
        let n = slots.count
        let base = "\(courses.count) matière\(courses.count > 1 ? "s" : "") · \(n) créneau\(n > 1 ? "x" : "")"
        guard let sync = timetables.first?.lastSuccessAt else { return base }
        return base + " · importé le " + sync.formatted(.dateTime.day().month(.abbreviated))
    }

    private func courseSubtitle(_ course: Course) -> String {
        let count = slots.filter { $0.course?.id == course.id }.count
        let base = "\(count) créneau\(count > 1 ? "x" : "")"
        guard let teacher = course.teacher else { return base }
        return "\(base) · \(teacher)"
    }

    // MARK: Coller le lien

    private var urlStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Colle le lien d'export ICS de ton ENT — ADE, Hyperplanning, Google Agenda. Le fichier est lu sur ton appareil : rien n'en sort.")
                .font(KFont.body(13.5, weight: .bold))
                .foregroundStyle(K.inkBody)
                .fixedSize(horizontal: false, vertical: true)

            TextField("https://…/calendrier.ics", text: $url)
                .textFieldStyle(.plain)
                .font(KFont.mono(12))
                .foregroundStyle(K.ink)
                .padding(14)
                .sticker(fill: K.paperAlt, radius: 14, state: .done)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                #endif

            if let errorMessage {
                Text(errorMessage)
                    .font(KFont.body(12.5, weight: .bold))
                    .foregroundStyle(K.paperAlt)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(K.alertBg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(K.ink, lineWidth: 2.5))
            }

            HStack(spacing: 12) {
                // Un lien ENT n'est pas toujours sous la main le premier jour :
                // l'import se refait depuis les cahiers a tout moment.
                if onFinish != nil {
                    Button("Plus tard") { close() }
                        .buttonStyle(StickerButtonStyle(kind: .secondary))
                }
                Button(isLoading ? "Lecture…" : "Importer") { load() }
                    .buttonStyle(StickerButtonStyle(kind: .primary))
                    .disabled(isLoading || url.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 28)
    }

    // MARK: Valider les matieres

    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Un emploi du temps ne dit pas quelles sont tes matieres : il donne des intitules qui changent d'une semaine a l'autre. Voici ce qu'on en deduit — corrige ce qui ne va pas.")
                .font(KFont.body(13, weight: .bold))
                .foregroundStyle(K.inkBody)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 28)

            ScrollView {
                VStack(spacing: 10) {
                    ForEach($proposals) { $proposal in
                        proposalRow($proposal)
                    }
                }
                .padding(.horizontal, 28)
            }
            .scrollIndicators(.hidden)

            HStack(spacing: 12) {
                Button("Retour") { proposals = []; events = [] }
                    .buttonStyle(StickerButtonStyle(kind: .secondary))
                Button("Créer \(acceptedCount) matières") { commit() }
                    .buttonStyle(StickerButtonStyle(kind: .primary))
                    .disabled(acceptedCount == 0)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 22)
        }
    }

    private func proposalRow(_ proposal: Binding<TimetableImporter.Proposal>) -> some View {
        HStack(spacing: 13) {
            Button {
                proposal.wrappedValue.isAccepted.toggle()
            } label: {
                CheckBadge(kind: .task, isChecked: proposal.wrappedValue.isAccepted)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                TextField("Nom de la matière", text: proposal.name)
                    .textFieldStyle(.plain)
                    .font(KFont.body(14, weight: .extraBold))
                    .foregroundStyle(K.ink)
                MetaText(subtitle(for: proposal.wrappedValue))
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .sticker(fill: K.paperAlt, radius: 14,
                 state: proposal.wrappedValue.isAccepted ? .rest : .upcoming)
    }

    private func subtitle(for proposal: TimetableImporter.Proposal) -> String {
        let slots = "\(proposal.group.occurrences) créneaux"
        guard let teacher = proposal.group.teacher else { return slots }
        return "\(slots) · \(teacher)"
    }

    private var acceptedCount: Int { proposals.filter(\.isAccepted).count }

    // MARK: Actions

    private func load() {
        errorMessage = nil
        isLoading = true
        Task {
            do {
                let result = try await TimetableImporter.preview(urlString: url)
                await MainActor.run {
                    proposals = result.proposals
                    events = result.events
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    private func commit() {
        TimetableImporter.commit(proposals: proposals, events: events, url: url, context: context)
        close()
    }
}
