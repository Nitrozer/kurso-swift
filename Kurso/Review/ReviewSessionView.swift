import SwiftUI
import SwiftData
import KursoCore
import KursoModels

/// L'ecran de session — l'onglet REVISER.
struct ReviewSessionView: View {
    @Environment(\.modelContext) private var context
    @Query private var allCards: [Card]

    @State private var queue: [Card] = []
    @State private var session: ReviewSession?
    @State private var isRevealed = false
    @State private var player: PlayerState?

    var body: some View {
        Group {
            if let session {
                switch session.outcome {
                case .inProgress:  card(session)
                case .finished:    summary(session, ranOut: false)
                case .outOfGommes: summary(session, ranOut: true)
                }
            } else if dueCards.isEmpty {
                EmptyState(
                    title: "Rien a reviser",
                    message: "Les cartes reviennent quand elles sont dues. Masque une zone de diapo pour en creer."
                )
            } else {
                start
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(K.paper)
        .task { loadPlayer() }
    }

    // MARK: Ecran de depart

    private var start: some View {
        VStack(spacing: 18) {
            DisplayText("\(dueCards.count) cartes t'attendent", size: 28)
            gommeRow
            Button("Commencer") { begin() }
                .buttonStyle(StickerButtonStyle(kind: .primary))
                .frame(maxWidth: 280)
        }
        .padding(28)
    }

    // MARK: La carte

    private func card(_ session: ReviewSession) -> some View {
        VStack(spacing: 0) {
            topBar(session)

            Spacer(minLength: 0)
            VStack(spacing: 20) {
                Text(current?.question ?? "")
                    .font(KFont.display(28))
                    .foregroundStyle(K.ink)
                    .multilineTextAlignment(.center)

                if isRevealed {
                    Text(current?.answerText ?? "—")
                        .font(KFont.body(18, weight: .bold))
                        .foregroundStyle(K.inkBody)
                        .multilineTextAlignment(.center)
                        .padding(20)
                        .frame(maxWidth: .infinity)
                        .sticker(fill: K.paperAlt, radius: 18, state: .done)
                }
            }
            .padding(28)
            .frame(maxWidth: 620)
            Spacer(minLength: 0)

            answers
        }
    }

    private func topBar(_ session: ReviewSession) -> some View {
        HStack(spacing: 14) {
            MetaText("Carte \(min(session.index + 1, session.cardCount)) sur \(session.cardCount)")
            Spacer(minLength: 0)
            if session.combo > 1 {
                Text("×\(session.combo)")
                    .font(KFont.display(20))
                    .foregroundStyle(K.ink)
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(K.reward, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(K.ink, lineWidth: 3))
            }
            gommes(session.gommes)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) { Rectangle().fill(K.ink).frame(height: 3) }
    }

    @ViewBuilder private var answers: some View {
        if isRevealed {
            HStack(spacing: 12) {
                Button("Je sechais") { answer(.failed) }
                    .buttonStyle(StickerButtonStyle(kind: .secondary))
                Button("A peu pres") { answer(.almost) }
                    .buttonStyle(StickerButtonStyle(kind: .brand))
                Button("Je savais") { answer(.knew) }
                    .buttonStyle(StickerButtonStyle(kind: .confirm))
            }
            .padding(24)
        } else {
            Button("Verifier") { isRevealed = true }
                .buttonStyle(StickerButtonStyle(kind: .primary))
                .padding(24)
                .frame(maxWidth: 420)
        }
    }

    // MARK: Fin de session

    private func summary(_ session: ReviewSession, ranOut: Bool) -> some View {
        VStack(spacing: 16) {
            DisplayText(ranOut ? "Plus de gommes" : "Session terminee", size: 30)
            Text(ranOut
                 ? "Les \(session.unseenCount) cartes non vues ne sont pas penalisees. Elles reviendront comme prevu."
                 : "\(session.xpEarned) XP gagnes\(session.isPerfect ? " · sans une faute" : "")")
                .font(KFont.body(14, weight: .bold))
                .foregroundStyle(K.inkBody)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button("Revenir") { reset() }
                .buttonStyle(StickerButtonStyle(kind: .primary))
                .frame(maxWidth: 280)
        }
        .padding(28)
        .frame(maxWidth: 460)
    }

    // MARK: Gommes

    private var gommeRow: some View { gommes(player?.gommesRemaining ?? GameValues.maxGommes) }

    private func gommes(_ remaining: Int) -> some View {
        HStack(spacing: 5) {
            ForEach(0..<GameValues.maxGommes, id: \.self) { index in
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(index < remaining ? K.eraser : K.ink.opacity(0.14))
                    .frame(width: 13, height: 17)
                    .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(K.ink, lineWidth: 2.5))
            }
        }
    }

    // MARK: Donnees

    private var dueCards: [Card] {
        allCards.filter { $0.dueAt <= .now }.sorted { $0.dueAt < $1.dueAt }
    }

    private var current: Card? {
        guard let session, session.index < queue.count else { return nil }
        return queue[session.index]
    }

    private func loadPlayer() {
        if let existing = try? context.fetch(FetchDescriptor<PlayerState>()).first {
            player = existing
        } else {
            let new = PlayerState()
            context.insert(new)
            try? context.save()
            player = new
        }
        regenerateGommes()
    }

    /// Les gommes remontent d'une toutes les quatre heures, meme app fermee.
    private func regenerateGommes() {
        guard let player else { return }
        let result = GameValues.regenerate(remaining: player.gommesRemaining, since: player.lastGommeRegenAt)
        player.gommesRemaining = result.remaining
        player.lastGommeRegenAt = result.lastRegen
        try? context.save()
    }

    private func begin() {
        let size = ReviewSession.defaultSize
        queue = Array(dueCards.prefix(size))
        session = ReviewSession(
            cardCount: queue.count,
            gommes: player?.gommesRemaining ?? GameValues.maxGommes,
            hasFullVersion: player?.hasFullVersion ?? false
        )
        isRevealed = false
    }

    private func answer(_ answer: SpacedRepetition.Answer) {
        guard var session, let card = current else { return }

        // La carte vue est mise a jour ; les non vues gardent leur dueAt.
        var state = SpacedRepetition.State(
            interval: card.interval, ease: card.ease, lapses: card.lapses
        )
        state = SpacedRepetition.apply(answer, to: state)
        card.interval = state.interval
        card.ease = state.ease
        card.lapses = state.lapses
        card.isInMistakeBook = SpacedRepetition.isInMistakeBook(state)
        card.dueAt = SpacedRepetition.dueDate(from: state)

        let gained = session.answer(answer)
        if let player {
            player.xp += gained
            player.level = GameValues.level(forTotalXP: player.xp)
            player.gommesRemaining = session.gommes
            player.shavings += answer == .failed ? 0 : GameValues.shavingsPerCard
        }
        try? context.save()

        self.session = session
        isRevealed = false
    }

    private func reset() {
        session = nil
        queue = []
        isRevealed = false
    }
}
