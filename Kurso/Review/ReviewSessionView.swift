import SwiftUI
import SwiftData
import KursoCore
import KursoModels
import PencilKit

/// L'ecran de session — l'onglet REVISER.
struct ReviewSessionView: View {
    /// Les cartes d'un sprint de fin de cours. Nil : session ordinaire.
    var sprintCardIDs: [UUID]?

    @Environment(\.modelContext) private var context
    @Query private var allCards: [Card]

    @State private var queue: [Card] = []
    @State private var session: ReviewSession?
    @State private var isRevealed = false
    @State private var player: PlayerState?
    @State private var isMistakeBookRun = false

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
                    title: "Rien à réviser",
                    message: "Les cartes reviennent quand elles sont dues. Masque une zone de diapo pour en créer."
                )
            } else {
                start
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(K.paper)
        .task {
            loadPlayer()
            #if DEBUG
            // Permet d'inspecter l'ecran de carte sans pouvoir taper.
            if ProcessInfo.processInfo.arguments.contains("-autoStartReview"), session == nil {
                begin()
                isRevealed = true
            }
            #endif
        }
    }

    // MARK: Ecran de depart

    private var start: some View {
        VStack(spacing: 18) {
            DisplayText("\(dueCards.count) cartes t'attendent", size: 28)
            gommeRow
            Button("Commencer") { begin() }
                .buttonStyle(StickerButtonStyle(kind: .primary))
                .frame(maxWidth: 280)

            if !mistakeCards.isEmpty { mistakeBookEntry }
        }
        .padding(28)
    }

    /// Le carnet des ratés : les cartes echouees deux fois. A dix, c'est un boss.
    private var mistakeBookEntry: some View {
        Button { begin(mistakeBookOnly: true) } label: {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(isBoss ? "BOSS" : "CARNET DES RATÉS")
                        .font(KFont.body(10, weight: .extraBold))
                        .tracking(0.8)
                        .foregroundStyle(K.paperAlt)
                        .padding(.horizontal, 9).padding(.vertical, 3)
                        .background(isBoss ? K.alertBg : K.ink, in: Capsule())
                    Spacer(minLength: 0)
                }
                Text("\(mistakeCards.count) carte\(mistakeCards.count > 1 ? "s" : "") ratée\(mistakeCards.count > 1 ? "s" : "") deux fois")
                    .font(KFont.body(13.5, weight: .extraBold))
                    .foregroundStyle(K.ink)
                Text(isBoss
                     ? "Vide-le en une session sans faute pour une fiche or."
                     : "Vide-le en une session sans faute pour remettre les compteurs à zéro.")
                    .font(KFont.body(12, weight: .bold))
                    .foregroundStyle(K.inkBody)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: 380, alignment: .leading)
            .sticker(fill: isBoss ? K.reward : K.paperAlt, radius: 16)
        }
        .buttonStyle(.plain)
        .padding(.top, 10)
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

                // Une carte tiree d'une diapo montre la diapo : la zone reste
                // couverte tant qu'on n'a pas repondu.
                if let slide = slideImage {
                    OcclusionPreview(image: slide,
                                     hidden: current?.occlusionRect,
                                     isRevealed: isRevealed)
                        .frame(maxHeight: 340)
                        .sticker(fill: K.paperAlt, radius: 18, state: isRevealed ? .done : .rest)
                }

                if isRevealed { verso }
            }
            .padding(28)
            .frame(maxWidth: 620)
            Spacer(minLength: 0)

            answers
        }
    }

    /// Le verso. Une carte capturee au geste porte le trace manuscrit, pas du
    /// texte : l'afficher comme du texte ne montrait qu'un tiret.
    @ViewBuilder private var verso: some View {
        if let image = versoImage {
            image
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 220)
                .padding(20)
                .frame(maxWidth: .infinity)
                .sticker(fill: K.paperAlt, radius: 18, state: .done)
        } else if let text = current?.answerText, !text.isEmpty {
            Text(text)
                .font(KFont.body(18, weight: .bold))
                .foregroundStyle(K.inkBody)
                .multilineTextAlignment(.center)
                .padding(20)
                .frame(maxWidth: .infinity)
                .sticker(fill: K.paperAlt, radius: 18, state: .done)
        } else {
            Text("Cette carte n'a pas de verso enregistré.")
                .font(KFont.body(13, weight: .bold))
                .foregroundStyle(K.inkSoft)
        }
    }

    /// La diapo enregistree avec la carte, s'il y en a une.
    private var slideImage: CGImage? {
        guard let data = current?.imageData else { return nil }
        #if canImport(UIKit)
        return UIImage(data: data)?.cgImage
        #else
        return NSImage(data: data)?.cgImage(forProposedRect: nil, context: nil, hints: nil)
        #endif
    }

    private var versoImage: Image? {
        guard let data = current?.answerDrawing,
              let drawing = try? PKDrawing(data: data),
              !drawing.bounds.isEmpty else { return nil }
        let rendered = drawing.image(from: drawing.bounds, scale: 3)
        #if canImport(UIKit)
        return Image(uiImage: rendered)
        #else
        return Image(nsImage: rendered)
        #endif
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
                Button("Je séchais") { answer(.failed) }
                    .buttonStyle(StickerButtonStyle(kind: .secondary))
                Button("A peu près") { answer(.almost) }
                    .buttonStyle(StickerButtonStyle(kind: .brand))
                Button("Je savais") { answer(.knew) }
                    .buttonStyle(StickerButtonStyle(kind: .confirm))
            }
            .padding(24)
        } else {
            Button("Vérifier") { isRevealed = true }
                .buttonStyle(StickerButtonStyle(kind: .primary))
                .padding(24)
                .frame(maxWidth: 420)
        }
    }

    // MARK: Fin de session

    private func summary(_ session: ReviewSession, ranOut: Bool) -> some View {
        VStack(spacing: 16) {
            DisplayText(ranOut ? "Plus de gommes" : "Session terminée", size: 30)
            Text(summaryMessage(session, ranOut: ranOut))
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

    private func summaryMessage(_ session: ReviewSession, ranOut: Bool) -> String {
        if ranOut {
            return "Les \(session.unseenCount) cartes non vues ne sont pas pénalisées. Elles reviendront comme prévu."
        }
        var text = "\(session.xpEarned) XP gagnés\(session.isPerfect ? " · sans une faute" : "")"
        if isMistakeBookRun {
            let reward = MistakeBook.evaluate(
                bookSize: session.cardCount,
                answered: session.index,
                failures: session.mistakes
            )
            if reward.goldCard {
                text += "\nCarnet vidé — fiche or débloquée."
            } else if reward.clearedEntirely {
                text += "\nCarnet vidé, compteurs remis à zéro."
            }
        }
        return text
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
        // Un sprint ne revise que ce qu'on vient d'ecrire, pas tout l'arriere.
        if let sprintCardIDs {
            let wanted = Set(sprintCardIDs)
            return allCards.filter { wanted.contains($0.id) }
        }
        return allCards.filter { $0.dueAt <= .now }.sorted { $0.dueAt < $1.dueAt }
    }

    /// Toutes les cartes du carnet, dues ou non : on vient les affronter.
    private var mistakeCards: [Card] {
        allCards.filter { MistakeBook.contains(lapses: $0.lapses) }
    }

    private var isBoss: Bool { MistakeBook.isBoss(count: mistakeCards.count) }

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

    private func begin(mistakeBookOnly: Bool = false) {
        isMistakeBookRun = mistakeBookOnly
        // Le carnet se joue en entier : le vider a moitie ne compte pas.
        queue = mistakeBookOnly ? mistakeCards : Array(dueCards.prefix(ReviewSession.defaultSize))
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

        let gained = session.answer(answer, isSprint: sprintCardIDs != nil)
        DailyActivityStore.record(.reviewCards, context: context)
        if let player {
            player.xp += gained
            player.level = GameValues.level(forTotalXP: player.xp)
            player.gommesRemaining = session.gommes
            player.shavings += answer == .failed ? 0 : GameValues.shavingsPerCard
        }
        // La serie avance quand une session est terminee, pas a chaque carte.
        if session.outcome == .finished, let player {
            let updated = StreakRule.sessionFinished(
                StreakRule.State(streak: player.streak,
                                 record: player.recordStreak,
                                 lastDay: player.lastStreakDay,
                                 freezes: player.freezesRemaining)
            )
            player.streak = updated.streak
            player.recordStreak = updated.record
            player.lastStreakDay = updated.lastDay
            player.freezesRemaining = updated.freezes
        }
        try? context.save()

        // Carnet vide en une session sans faute : les compteurs repartent a zero.
        if isMistakeBookRun, session.outcome == .finished,
           MistakeBook.evaluate(bookSize: session.cardCount,
                                answered: session.index,
                                failures: session.mistakes).clearedEntirely {
            for card in queue {
                card.lapses = 0
                card.isInMistakeBook = false
            }
            try? context.save()
        }

        self.session = session
        isRevealed = false
    }

    private func reset() {
        session = nil
        queue = []
        isRevealed = false
    }
}
