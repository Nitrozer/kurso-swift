import SwiftUI
import SwiftData
import KursoCore
import KursoModels

/// Import de l'emploi du temps, en deux temps : coller le lien, puis valider
/// les matieres detectees (§6, ecran 03).
///
/// Rien n'est cree avant la validation : le regroupement est une proposition,
/// jamais une decision prise a la place de l'etudiant.
struct TimetableOnboardingView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var url = ""
    @State private var proposals: [TimetableImporter.Proposal] = []
    @State private var events: [ICSEvent] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if proposals.isEmpty { urlStep } else { reviewStep }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(K.paper)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            MetaText(proposals.isEmpty ? "Etape 1 sur 2" : "Etape 2 sur 2")
            DisplayText(proposals.isEmpty ? "Ton emploi du temps" : "\(proposals.count) matieres detectees", size: 30)
        }
        .padding(.horizontal, 28)
        .padding(.top, 26)
        .padding(.bottom, 18)
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

            Button(isLoading ? "Lecture…" : "Importer") { load() }
                .buttonStyle(StickerButtonStyle(kind: .primary))
                .disabled(isLoading || url.trimmingCharacters(in: .whitespaces).isEmpty)

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
                Button("Creer \(acceptedCount) matieres") { commit() }
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
                TextField("Nom de la matiere", text: proposal.name)
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
        let slots = "\(proposal.group.occurrences) creneaux"
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
        dismiss()
    }
}
