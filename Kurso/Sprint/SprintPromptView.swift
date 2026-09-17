import SwiftUI
import SwiftData
import KursoCore
import KursoModels

/// Fin de seance : trois cartes tirees de ce qu'on vient d'ecrire.
///
/// C'est le seul moment ou Kurso propose des cartes de lui-meme, et jamais
/// plus de trois. Rien n'est redige : on decoupe une ligne en question et
/// reponse, mot pour mot (§12 interdit de generer du contenu).
struct SprintPromptView: View {
    let page: Page
    let proposals: [CardProposer.Proposal]
    /// Demande depuis le menu de la page, et non a la fin d'un cours.
    var isManual = false
    /// Rend les cartes retenues, prêtes pour le sprint.
    var onStart: ([Card]) -> Void
    var onSkip: () -> Void

    @Environment(\.modelContext) private var context
    @State private var kept: Set<Int> = []
    @State private var questions: [Int: String] = [:]

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(K.paper)
            .onAppear { kept = Set(proposals.map(\.id)) }
    }

    @ViewBuilder
    private var content: some View {
        if proposals.isEmpty {
            nothingToCut
        } else {
            VStack(alignment: .leading, spacing: 0) {
                header
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 16)], spacing: 16) {
                        ForEach(proposals) { proposal in
                            card(proposal)
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 16)
                }
                .scrollIndicators(.hidden)
                footer
            }
        }
    }

    // MARK: Quand il n'y a rien a decouper

    /// Un ecran vide qui annonce « 0 carte » laisse croire que le bouton est
    /// casse. Il dit ce que Kurso cherche, et montre la ligne qui marche.
    private var nothingToCut: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(meta)
                .font(KFont.mono(11))
                .tracking(1.2)
                .foregroundStyle(K.inkSoft)
                .padding(.horizontal, 28)
                .padding(.top, 26)

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 16) {
                DisplayText(unreadable ? "Ton écriture n'a pas pu être relue."
                                       : "Rien à découper dans cette page.", size: 30)

                Text(unreadable
                     ? "La relecture se fait sur l'appareil, et elle bute parfois. Écris une ligne de plus, puis redemande."
                     : "Kurso ne rédige pas : il retourne en carte les lignes où tu poses un terme et sa définition. Il n'y en a aucune ici.")
                    .font(KFont.body(14, weight: .bold))
                    .foregroundStyle(K.inkBody)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 560, alignment: .leading)

                VStack(alignment: .leading, spacing: 10) {
                    Text("CE QU'IL CHERCHE")
                        .font(KFont.body(10, weight: .extraBold))
                        .tracking(1.1)
                        .foregroundStyle(K.inkSoft)
                    Text("Correcteur PID : annule l'erreur statique")
                        .font(KFont.mono(14))
                        .foregroundStyle(K.ink)
                    HStack(spacing: 10) {
                        Text("donne")
                            .font(KFont.body(12, weight: .bold))
                            .foregroundStyle(K.inkSoft)
                        Text("Correcteur PID ?")
                            .font(KFont.body(12.5, weight: .extraBold))
                            .foregroundStyle(K.ink)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(K.paper, in: Capsule())
                            .overlay(Capsule().strokeBorder(K.ink.opacity(0.18), lineWidth: 2))
                        Text("annule l'erreur statique")
                            .font(KFont.body(12.5, weight: .bold))
                            .foregroundStyle(K.inkBody)
                    }
                    Text("Deux-points, égale, flèche ou tiret : au choix. C'est toi qui décides de ce qui mérite une carte, en l'écrivant comme ça.")
                        .font(KFont.body(12, weight: .bold))
                        .foregroundStyle(K.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 520, alignment: .leading)
                }
                .padding(18)
                .frame(maxWidth: 620, alignment: .leading)
                .background(K.paperAlt, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(K.ink, lineWidth: 2.5))
            }
            .padding(.horizontal, 28)

            Spacer(minLength: 0)

            HStack(spacing: 16) {
                GribouView(mood: .idle, size: 78)
                Text("Rien n'a été créé, et rien n'a été perdu. Ta page est intacte.")
                    .font(KFont.body(12.5, weight: .bold))
                    .foregroundStyle(K.inkBody)
                Spacer(minLength: 0)
                Button("Fermer") { onSkip() }
                    .buttonStyle(StickerButtonStyle(kind: .primary))
                    .frame(width: 200)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 22)
        }
    }

    /// Aucune reconnaissance n'a abouti : ce n'est pas la meme chose que des
    /// notes sans definition, et on ne dit donc pas la meme phrase.
    private var unreadable: Bool {
        (page.recognizedText ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: En-tete

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 7) {
                Text(meta)
                    .font(KFont.mono(11))
                    .tracking(1.2)
                    .foregroundStyle(K.inkSoft)
                DisplayText("\(proposals.count) carte\(proposals.count > 1 ? "s" : "") tirée\(proposals.count > 1 ? "s" : "") de ce que tu viens d'écrire.", size: 32)
                Text(isManual
                     ? "Garde, modifie, ou jette. Kurso découpe ce que tu as écrit, il n'invente rien — et jamais plus de trois."
                     : "Garde, modifie, ou jette. C'est le seul moment où Kurso propose des cartes tout seul — et jamais plus de trois.")
                    .font(KFont.body(13.5, weight: .bold))
                    .foregroundStyle(K.inkBody)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 620, alignment: .leading)
            }
            Spacer(minLength: 0)
            sprintBadge
        }
        .padding(.horizontal, 28)
        .padding(.top, 26)
        .padding(.bottom, 20)
    }

    private var meta: String {
        let hour = Date.now.formatted(.dateTime.hour().minute())
        let course = page.course?.name.uppercased() ?? "SANS MATIÈRE"
        return "\(isManual ? "À LA DEMANDE" : "FIN DE SÉANCE") · \(hour) · \(course)"
    }

    private var sprintBadge: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("SPRINT À CHAUD")
                .font(KFont.body(11, weight: .extraBold))
                .tracking(0.8)
                .foregroundStyle(K.ink)
            Text("×2 sur les XP")
                .font(KFont.body(11, weight: .bold))
                .foregroundStyle(K.ink.opacity(0.65))
        }
        .padding(.horizontal, 16).padding(.vertical, 11)
        .sticker(fill: K.reward, radius: 16)
    }

    // MARK: Une proposition

    private func card(_ proposal: CardProposer.Proposal) -> some View {
        let isKept = kept.contains(proposal.id)
        return VStack(alignment: .leading, spacing: 11) {
            HStack {
                Text("RECTO / VERSO")
                    .font(KFont.mono(9.5))
                    .tracking(0.9)
                    .foregroundStyle(K.brand)
                    .padding(.horizontal, 9).padding(.vertical, 3)
                    .background(K.brand.opacity(0.12), in: Capsule())
                Spacer(minLength: 0)
                Text("LIGNE \(proposal.line + 1)")
                    .font(KFont.mono(9.5))
                    .foregroundStyle(K.inkSoft)
            }

            // La question se corrige : le verso, jamais (§4).
            TextField("Question", text: Binding(
                get: { questions[proposal.id] ?? proposal.question },
                set: { questions[proposal.id] = $0 }
            ))
            .textFieldStyle(.plain)
            .font(KFont.display(19))
            .foregroundStyle(K.ink)

            Divider().overlay(K.ink.opacity(0.15))

            Text(proposal.answer)
                .font(KFont.body(14, weight: .bold))
                .foregroundStyle(K.inkBody)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            Button {
                if isKept { kept.remove(proposal.id) } else { kept.insert(proposal.id) }
            } label: {
                Text(isKept ? "GARDÉE" : "GARDER")
                    .font(KFont.body(13, weight: .extraBold))
                    .foregroundStyle(isKept ? K.paperAlt : K.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(isKept ? K.success : .clear,
                                in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(K.ink, lineWidth: 2.5))
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .frame(minHeight: 230, alignment: .topLeading)
        .sticker(fill: K.paperAlt, radius: 20)
    }

    // MARK: Pied

    private var footer: some View {
        HStack(spacing: 16) {
            HStack(spacing: 14) {
                GribouView(mood: .fier, size: 78)
                Text("Kurso découpe une ligne en question et réponse. Il n'écrit pas ton cours, ne le résume pas, et ne garde rien sans ton accord.")
                    .font(KFont.body(12.5, weight: .bold))
                    .foregroundStyle(K.paperAlt.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(K.ink, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            VStack(spacing: 9) {
                Button(startLabel) { start() }
                    .buttonStyle(StickerButtonStyle(kind: .brand))
                    .disabled(kept.isEmpty)
                Button("Plus tard") { onSkip() }
                    .buttonStyle(StickerButtonStyle(kind: .secondary))
            }
            .frame(width: 260)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 22)
    }

    private var startLabel: String {
        kept.isEmpty ? "Aucune gardée" : "Garder \(kept.count) · lancer le sprint"
    }

    /// Les cartes retenues deviennent de vraies cartes, dues tout de suite :
    /// le sprint sert justement a les affronter a chaud.
    private func start() {
        var created: [Card] = []
        for proposal in proposals where kept.contains(proposal.id) {
            let card = Card(
                question: (questions[proposal.id] ?? proposal.question)
                    .trimmingCharacters(in: .whitespaces),
                kind: .frontBack,
                dueAt: .now
            )
            card.answerText = proposal.answer
            card.sourceLineRange = proposal.line..<(proposal.line + 1)
            card.page = page
            context.insert(card)
            created.append(card)
        }
        DailyActivityStore.record(.captureCard, amount: created.count, context: context)
        try? context.save()
        onStart(created)
    }
}
