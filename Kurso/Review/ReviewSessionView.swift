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
    /// A l'approche d'un partiel, la session change de forme (§9).
    @State private var isExamMode = false
    /// Le passage de niveau a montrer, s'il y en a un.
    @State private var celebration: ChestStore.Celebration?

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
        // Plein ecran : la maquette montre un fond bleu bord a bord, pas une
        // feuille posee sur la session.
        #if os(iOS)
        .fullScreenCover(item: $celebration) { won in
            LevelUpView(celebration: won) { celebration = nil }
        }
        #else
        .sheet(item: $celebration) { won in
            LevelUpView(celebration: won) { celebration = nil }
        }
        #endif
        .task {
            loadPlayer()
            isExamMode = SeasonStore.isExamMode(context)
            #if DEBUG
            // Ferme la fenetre de partiel : sert a verifier que les coffres
            // retenus par le mode partiel retombent bien apres, sans etre perdus.
            if ProcessInfo.processInfo.arguments.contains("-examOver") {
                SeasonStore.current(context)?.examDate = nil
                try? context.save()
                isExamMode = SeasonStore.isExamMode(context)
            }
            if ProcessInfo.processInfo.arguments.contains("-simulateChest") {
                let won = ChestStore.claim(context, isExamMode: isExamMode)
                print("[chest] " + (won.map {
                    "niveau \($0.level), \($0.rewards.count) coffre(s), \($0.shavings)cp, "
                        + "\($0.freezes) gel(s), couvertures \($0.covers.map(\.rawValue))"
                } ?? "aucun"))
                celebration = won
            }
            // Permet d'inspecter l'ecran de carte sans pouvoir taper.
            // Rejoue une session finie : aucun tap ne peut y mener ici.
            if ProcessInfo.processInfo.arguments.contains("-simulateSummary") {
                begin()
                var played = session ?? ReviewSession(cardCount: 8, gommes: 5)
                for index in 0..<played.cardCount {
                    played.answer(index == 2 ? .failed : .knew)
                }
                print("[RESUME] \(played.xpEarned) XP · \(played.index) vues · \(played.mistakes) ratees")
                session = played
            }
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

            GribouBubble(tips: reviewTips, mood: .concentre)
                .frame(maxWidth: 520)
                .padding(.top, 10)

            if !mistakeCards.isEmpty { mistakeBookEntry }
        }
        .padding(28)
    }

    /// Ce que Gribou pourrait dire avant une session.
    private var reviewTips: [GribouAdvice.Tip] {
        var tips: [GribouAdvice.Tip] = []

        if mistakeCards.count >= 3 {
            tips.append(.init(
                id: "reviser.carnet",
                kind: .action,
                text: "\(mistakeCards.count) cartes sont dans ton carnet des ratés. Elles reviennent tant qu'elles ne sont pas sues."))
        }

        let late = dueCards.filter { $0.dueAt < Date().addingTimeInterval(-7 * 86_400) }
        if late.count >= 3 {
            tips.append(.init(
                id: "reviser.retard",
                kind: .debrief,
                text: "\(late.count) cartes attendent depuis plus d'une semaine. Ce sont elles qui coûtent le plus cher à l'examen."))
        }

        tips.append(.init(
            id: "reviser.gommes",
            kind: .mechanic,
            text: "Une erreur coûte une gomme, jamais ton travail : la carte ratée revient demain, en tête de pile. Une gomme se regagne toutes les 4 h."))

        if dueCards.count <= 5, !dueCards.isEmpty {
            tips.append(.init(
                id: "reviser.court",
                kind: .cheer,
                text: "Courte session. Deux minutes et c'est plié."))
        }
        return tips
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
        HStack(alignment: .top, spacing: 0) {
            VStack(spacing: 0) {
                cardHeader(session)
                progressTrack(session)
                Spacer(minLength: 0)
                cardFace(session)
                Spacer(minLength: 0)
                answers
                    // Les boutons touchaient le bord bas de l'ecran.
                    .padding(.bottom, 18)
            }
            .frame(maxWidth: .infinity)

            Rectangle().fill(K.ink.opacity(0.1)).frame(width: 1)
            comboPanel(session).frame(width: 290)
        }
    }

    /// L'en-tete : d'ou vient la carte, ce qu'il reste de gommes, ou en est
    /// le combo, et la position dans la pile.
    private func cardHeader(_ session: ReviewSession) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(sourceLine)
                    .font(KFont.mono(10))
                    .tracking(1.1)
                    .foregroundStyle(K.inkSoft)
                Text(current?.page?.title.isEmpty == false ? current!.page!.title : "Carte capturée")
                    .font(KFont.display(19))
                    .foregroundStyle(K.ink)
            }
            Spacer(minLength: 8)
            gommes(session.gommes)
            if session.combo > 1 {
                Text("×\(session.combo)")
                    .font(KFont.display(18))
                    .foregroundStyle(K.ink)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(K.reward, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(K.ink, lineWidth: 3))
            }
            Text(String(format: "%02d", min(session.index + 1, session.cardCount)))
                .font(KFont.display(16))
                .foregroundStyle(K.ink)
                .frame(width: 44, height: 44)
                .background(K.paperAlt, in: Circle())
                .overlay(Circle().strokeBorder(K.brand, lineWidth: 3))
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 14)
    }

    /// La pile, un segment par carte : ce qui est passe, ou on en est, ce qui
    /// reste. Une barre continue ne dirait pas combien il en reste.
    private func progressTrack(_ session: ReviewSession) -> some View {
        HStack(spacing: 6) {
            ForEach(0..<max(1, session.cardCount), id: \.self) { index in
                Capsule()
                    .fill(index < session.index ? K.success
                          : index == session.index ? K.brand
                          : K.paperAlt)
                    .frame(height: 9)
                    .overlay(Capsule().strokeBorder(K.ink.opacity(index > session.index ? 0.2 : 0), lineWidth: 1.5))
            }
        }
        .padding(.horizontal, 26)
        .padding(.bottom, 6)
    }

    /// La carte elle-meme, posee comme un autocollant.
    private func cardFace(_ session: ReviewSession) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Text(isReversed(session) ? "À L'ENVERS" : "RECTO / VERSO")
                    .font(KFont.body(10.5, weight: .extraBold))
                    .tracking(0.9)
                    .foregroundStyle(K.brand)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(K.brand.opacity(0.12), in: Capsule())
                Text(captureLine)
                    .font(KFont.mono(9.5))
                    .tracking(0.9)
                    .foregroundStyle(K.inkSoft)
                Spacer(minLength: 0)
            }

            Text(prompt(session))
                .font(KFont.display(27))
                .foregroundStyle(K.ink)
                .fixedSize(horizontal: false, vertical: true)

            if let slide = slideImage {
                OcclusionPreview(image: slide,
                                 hidden: current?.occlusionRect,
                                 isRevealed: isRevealed)
                    .frame(maxHeight: 300)
            }
            if isRevealed { verso }
        }
        .padding(26)
        .frame(maxWidth: 680, alignment: .leading)
        .sticker(fill: K.paperAlt, radius: 22, state: .rest)
        .padding(.horizontal, 26)
    }

    /// L'echelle de combo. Montrer les crans qu'on n'a pas atteints est ce qui
    /// donne envie d'enchainer (§9).
    private func comboPanel(_ session: ReviewSession) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ÉCHELLE DE COMBO")
                .font(KFont.mono(9.5))
                .tracking(1.1)
                .foregroundStyle(K.inkSoft)

            ForEach(ComboScale.steps) { step in
                let reached = step.multiplier == session.combo
                HStack(spacing: 11) {
                    Text("×\(step.multiplier)")
                        .font(KFont.display(14))
                        .foregroundStyle(K.ink)
                        .frame(width: 30, alignment: .leading)
                    Text(step.label)
                        .font(KFont.body(12, weight: .extraBold))
                        .foregroundStyle(reached ? K.ink : K.inkBody)
                        .lineLimit(2)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(reached ? K.reward : K.paperAlt,
                            in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(reached ? K.ink : K.ink.opacity(0.12), lineWidth: reached ? 2.5 : 1.5))
            }

            Text(ComboScale.warningTitle)
                .font(KFont.mono(9.5))
                .tracking(1.1)
                .foregroundStyle(K.inkSoft)
                .padding(.top, 8)
            Text(ComboScale.warning)
                .font(KFont.body(12, weight: .bold))
                .foregroundStyle(K.inkBody)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 12)
            GribouView(mood: .concentre, size: 96)
                .frame(maxWidth: .infinity)
            Text(ComboScale.remaining(answered: session.index, total: session.cardCount))
                .font(KFont.body(11.5, weight: .extraBold))
                .foregroundStyle(K.inkSoft)
                .frame(maxWidth: .infinity)
        }
        .padding(20)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    /// « ALGORITHMIQUE · NŒUD 2 »
    private var sourceLine: String {
        let course = current?.page?.course?.name.uppercased() ?? "SANS MATIÈRE"
        return course
    }

    private var captureLine: String {
        guard let page = current?.page else { return "" }
        return "CAPTURÉE LE \(page.createdAt.formatted(.dateTime.day().month(.twoDigits)))"
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
        } else if let session, isReversed(session) {
            Text(current?.question ?? "")
                .font(KFont.body(18, weight: .bold))
                .foregroundStyle(K.inkBody)
                .multilineTextAlignment(.center)
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

    /// Une carte sur trois se tire a l'envers pendant le mode partiel :
    /// reconnaitre une reponse n'est pas la meme chose que la retrouver.
    private func isReversed(_ session: ReviewSession) -> Bool {
        ExamMode.isReversed(index: session.index, isExamMode: isExamMode)
    }

    /// Ce qu'on montre en premier.
    private func prompt(_ session: ReviewSession) -> String {
        guard isReversed(session) else { return current?.question ?? "" }
        let answer = current?.answerText ?? ""
        return answer.isEmpty ? (current?.question ?? "") : answer
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
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            VStack(spacing: 20) {
                GribouView(mood: ranOut ? .inquiet : (session.isPerfect ? .fier : .concentre), size: 132)

                VStack(spacing: 8) {
                    DisplayText(ranOut ? "Plus de gommes" : "Session terminée", size: 32)
                    Text(summaryMessage(session, ranOut: ranOut))
                        .font(KFont.body(14, weight: .bold))
                        .foregroundStyle(K.inkBody)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Le chiffre seul ne dit rien : trois tuiles disent ce qui
                // s'est passe, et laquelle merite qu'on y revienne.
                HStack(spacing: 12) {
                    summaryTile("\(session.xpEarned)", "XP GAGNÉS", K.reward)
                    summaryTile("\(session.index)", "CARTES VUES", K.brand)
                    summaryTile(session.mistakes == 0 ? "—" : "\(session.mistakes)",
                                "RATÉES", session.mistakes == 0 ? K.success : K.endangered)
                }

                if ranOut, session.unseenCount > 0 {
                    // La regle qui compte le plus (§9) : une session
                    // interrompue ne penalise pas les cartes non vues.
                    HStack(spacing: 12) {
                        Text("Les \(session.unseenCount) cartes non vues gardent leur date. Rien n'est perdu.")
                            .font(KFont.body(12.5, weight: .bold))
                            .foregroundStyle(K.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity)
                    .background(K.reward, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(K.ink, lineWidth: 2.5))
                }

                Button("Revenir") { reset() }
                    .buttonStyle(StickerButtonStyle(kind: .primary))
                    .frame(maxWidth: 320)
            }
            .padding(30)
            .frame(maxWidth: 520)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func summaryTile(_ value: String, _ label: String, _ tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(KFont.display(26))
                .foregroundStyle(K.ink)
            Text(label)
                .font(KFont.body(9.5, weight: .extraBold))
                .tracking(0.9)
                .foregroundStyle(K.inkSoft)
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(tint.opacity(0.22), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(K.ink, lineWidth: 2.5))
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
        // A l'approche d'un partiel, la session passe a vingt cartes, et les
        // plus fragiles d'abord : c'est le moment de rattraper, pas de reviser
        // ce qu'on sait deja.
        let size = ExamMode.sessionSize(isExamMode: isExamMode, ordinary: ReviewSession.defaultSize)
        let pool = isExamMode
            ? dueCards.sorted { $0.interval < $1.interval }
            : dueCards
        queue = mistakeBookOnly ? mistakeCards : Array(pool.prefix(size))
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
            DailyActivityStore.record(xp: gained, context: context)
            player.gommesRemaining = session.gommes
            player.shavings += answer == .failed ? 0 : GameValues.shavingsPerCard
        }
        // La serie avance quand une session est terminee, pas a chaque carte.
        // Pendant le mode partiel elle gele : elle n'avance plus, mais elle ne
        // casse pas non plus — on ne culpabilise pas quelqu'un qui revise.
        if session.outcome == .finished, !isExamMode, let player {
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
        // Un noeud entierement su rapporte, une seule fois (§9).
        if let page = card.page, page.masteredAt == nil {
            let cards = page.cards ?? []
            let allKnown = !cards.isEmpty && cards.allSatisfy {
                Fiche.isAcquired(interval: $0.interval, dueAt: $0.dueAt)
            }
            if allKnown {
                page.masteredAt = .now
                PlayerStore.award(shavings: Shop.Earn.masteredNode, context: context)
            }
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

        // Le coffre tombe a la fin de la session, pas au milieu d'une carte :
        // on ne coupe pas quelqu'un qui enchaine.
        if session.outcome != .inProgress {
            celebration = ChestStore.claim(context, isExamMode: isExamMode)
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
