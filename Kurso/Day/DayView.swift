import SwiftUI
import SwiftData
import KursoCore
import KursoModels

/// L'écran JOUR — l'accueil.
struct DayView: View {
    @Binding var tab: RailTab
    var onOpenPage: (Page) -> Void = { _ in }

    @Environment(\.modelContext) private var context
    @Query private var slots: [TimeSlot]
    @Query private var cards: [Card]
    @Query private var assignments: [Assignment]
    @Query private var activities: [DailyActivity]
    @Query(sort: \Page.createdAt, order: .reverse) private var pages: [Page]

    @State private var player: PlayerState?
    /// Le releve de fin de semestre, quand on le regarde.
    @State private var reportFor: Season?
    /// Mode partiel : le jeu se tait, la serie gele (§9).
    @State private var isExamMode = false
    @State private var activity: DailyActivity?
    @State private var now = Date()

    /// Le compte a rebours du cours doit avancer sans qu'on touche l'ecran.
    private let tick = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                // Le cours et la serie cote a cote : c'est la disposition du
                // prototype, et elle tient parce que les deux se lisent d'un
                // coup d'oeil en arrivant.
                HStack(alignment: .top, spacing: 18) {
                    // La carte bleue est toujours la : le soir ou entre deux
                    // cours elle bascule sur le prochain plutot que de
                    // disparaitre, sinon l'accueil se vide a moitie.
                    Group {
                        if let slot = featuredSlot {
                            courseCard(slot, live: currentSlot != nil)
                        } else {
                            freeDayCard
                        }
                    }
                    .frame(maxWidth: .infinity)
                    StreakCard(
                        streak: player?.streak ?? 0,
                        record: max(player?.recordStreak ?? 0, player?.streak ?? 0),
                        freezes: player?.freezesRemaining ?? 0,
                        gommes: player?.gommesRemaining ?? GameValues.maxGommes,
                        week: weekMarks,
                        gribouMood: Gribou.mood(for: gribouContext),
                        gribouLine: gribouSentence
                    )
                    .frame(maxWidth: 320)
                }

                if isExamMode { examBanner }
                if let season = closableSeason { seasonBanner(season) }

                HStack(alignment: .top, spacing: 18) {
                    questsColumn.frame(maxWidth: .infinity)
                    upcoming.frame(maxWidth: .infinity)
                    // Ni ligue ni coffre pendant les revisions : le jeu se
                    // tait, on ne joue pas a quinze jours d'un partiel (§9).
                    if !isExamMode { leagueColumn.frame(width: 200) }
                }

                reviewCTA
            }
            .padding(28)
            .frame(maxWidth: 1_020, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity)
        .background(K.paper)
        .onReceive(tick) { now = $0 }
        .task { load() }
        #if os(iOS)
        .fullScreenCover(item: $reportFor) { season in seasonReport(season) }
        #else
        .sheet(item: $reportFor) { season in seasonReport(season) }
        #endif
    }

    // MARK: En-tête

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                MetaText(dateLine, size: 11)
                DisplayText(greeting, size: 34)
            }
            Spacer(minLength: 0)
            HStack(spacing: 9) {
                pill(flame: true, value: "\(player?.streak ?? 0)")
                pill(flame: false, value: "\(player?.xp ?? 0)")
                gommePill
            }
        }
    }

    private var dateLine: String {
        let week = Calendar.current.component(.weekOfYear, from: now)
        return "\(now.formatted(.dateTime.weekday(.wide).day().month(.wide))) · semaine \(week)"
    }

    private var greeting: String {
        let streak = player?.streak ?? 0
        let who = (player?.displayName ?? "").isEmpty ? "" : " \(player?.displayName ?? "")"
        return streak > 0
            ? "Salut\(who), \(streak) jour\(streak > 1 ? "s" : "") d'affilée."
            : "Salut\(who)."
    }

    private func pill(flame: Bool, value: String) -> some View {
        HStack(spacing: 8) {
            if flame {
                FlameShape().fill(K.reward)
                    .overlay(FlameShape().stroke(K.ink, lineWidth: 2.5))
                    .frame(width: 15, height: 18)
            } else {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(K.brand)
                    .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(K.ink, lineWidth: 2.5))
                    .frame(width: 15, height: 15)
                    .rotationEffect(.degrees(45))
            }
            Text(value).font(KFont.display(17)).foregroundStyle(K.ink)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(K.paperAlt, in: Capsule())
        .overlay(Capsule().strokeBorder(K.ink, lineWidth: 3))
        .background(alignment: .top) { Capsule().fill(K.ink).offset(y: 3) }
    }

    /// Les gommes en tete, comme dans le prototype : cinq formes, puis le compte.
    private var gommePill: some View {
        let remaining = player?.gommesRemaining ?? GameValues.maxGommes
        return HStack(spacing: 5) {
            ForEach(0..<GameValues.maxGommes, id: \.self) { index in
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(index < remaining ? K.eraser : K.paperAlt)
                    .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(K.ink, lineWidth: 2.5))
                    .frame(width: 13, height: 17)
            }
            Text("\(remaining)/\(GameValues.maxGommes)")
                .font(KFont.mono(10.5))
                .foregroundStyle(K.ink)
                .fixedSize()
        }
        .padding(.horizontal, 13).padding(.vertical, 8)
        .background(K.paperAlt, in: Capsule())
        .overlay(Capsule().strokeBorder(K.ink, lineWidth: 3))
        .background(alignment: .top) { Capsule().fill(K.ink).offset(y: 3) }
    }

    // MARK: Cours en cours

    /// Le cours mis en avant : celui en cours, sinon le prochain a venir.
    private var featuredSlot: TimeSlot? { currentSlot ?? nextSlots.first }

    /// Quand l'emploi du temps ne propose plus rien, la place de la carte
    /// bleue reste occupee.
    private var freeDayCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("JOURNÉE LIBRE")
                .font(KFont.body(11, weight: .extraBold)).tracking(1)
                .foregroundStyle(K.ink)
                .padding(.horizontal, 12).padding(.vertical, 4)
                .background(K.paper, in: Capsule())
                .overlay(Capsule().strokeBorder(K.ink, lineWidth: 2.5))
            Text("Pas de cours prévu")
                .font(KFont.display(34))
                .foregroundStyle(K.paperAlt)
            Text(dueCards.isEmpty
                 ? "Rien à réviser non plus. Profites-en."
                 : "Bon moment pour descendre \(dueCards.count == 1 ? "ta carte" : "tes \(dueCards.count) cartes").")
                .font(KFont.body(13.5, weight: .bold))
                .foregroundStyle(K.paperAlt)
            Spacer(minLength: 0)
        }
        .padding(22)
        .frame(maxWidth: .infinity, minHeight: 210, alignment: .leading)
        .sticker(fill: K.brand, radius: 26)
    }

    private func courseCard(_ slot: TimeSlot, live: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(live ? "EN COURS" : "PROCHAIN COURS")
                    .font(KFont.body(11, weight: .extraBold)).tracking(1)
                    .foregroundStyle(K.ink)
                    .padding(.horizontal, 12).padding(.vertical, 4)
                    .background(K.paper, in: Capsule())
                    .overlay(Capsule().strokeBorder(K.ink, lineWidth: 2.5))
                Spacer(minLength: 0)
                if let location = slot.location {
                    Text(location).font(KFont.display(16)).foregroundStyle(K.paperAlt)
                }
            }

            Text(slot.course?.name ?? slot.summary)
                .font(KFont.display(34))
                .foregroundStyle(K.paperAlt)

            HStack(alignment: .bottom) {
                Text(timeRange(slot))
                    .font(KFont.body(13.5, weight: .bold))
                    .foregroundStyle(K.paperAlt)
                Spacer(minLength: 0)
                let figure = countdown(slot, live: live)
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(figure.value).font(KFont.display(48)).foregroundStyle(K.paperAlt)
                    Text(figure.unit).font(KFont.body(13, weight: .extraBold)).foregroundStyle(K.paperAlt)
                }
            }

            HStack(spacing: 9) {
                courseStat("\(dueCards.count)", "cartes dues")
                courseStat("\(coursePageCount(slot))", "pages")
                courseStat(acquisitionLabel(slot), "acquis")
            }
            .padding(.top, 4)

            Button {
                openOrCreatePage(for: slot)
            } label: {
                HStack(spacing: 9) {
                    Glyph(kind: .pencil, size: 15)
                    Text("Ouvrir le cahier")
                        .font(KFont.body(14, weight: .extraBold))
                        .foregroundStyle(K.ink)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .sticker(fill: K.paperAlt, radius: 16)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sticker(fill: K.brand, radius: 26)
    }

    /// Les encadres du prototype : fond sombre translucide sur le bleu.
    private func courseStat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value).font(KFont.display(20)).foregroundStyle(K.paperAlt)
            Text(label.uppercased())
                .font(KFont.body(9, weight: .extraBold))
                .tracking(0.4)
                .foregroundStyle(K.paperAlt)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12).padding(.vertical, 11)
        .background(K.ink.opacity(0.22), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func coursePageCount(_ slot: TimeSlot) -> Int {
        pages.filter { $0.course?.id == slot.course?.id }.count
    }

    private func acquisitionLabel(_ slot: TimeSlot) -> String {
        let withCards = pages.filter { $0.course?.id == slot.course?.id && !($0.cards ?? []).isEmpty }
        guard !withCards.isEmpty else { return "—" }
        let mean = withCards.map { page in
            Freshness.compute(cards: (page.cards ?? []).map {
                Freshness.CardState(dueAt: $0.dueAt, interval: $0.interval)
            })
        }.reduce(0, +) / Double(withCards.count)
        return "\(Int(mean * 100)) %"
    }

    private func timeRange(_ slot: TimeSlot) -> String {
        let cal = Calendar.current
        let day = cal.isDateInToday(slot.start) ? ""
            : cal.isDateInTomorrow(slot.start) ? "demain "
            : slot.start.formatted(.dateTime.weekday(.wide)) + " "
        let start = day + slot.start.formatted(.dateTime.hour().minute())
        let end = slot.end.formatted(.dateTime.hour().minute())
        guard let teacher = slot.course?.teacher else { return "\(start) → \(end)" }
        return "\(start) → \(end) · \(teacher)"
    }

    /// Le grand chiffre de la carte. Un cours lointain affiche son heure de
    /// debut : « dans 940 min » ne veut rien dire.
    private func countdown(_ slot: TimeSlot, live: Bool) -> (value: String, unit: String) {
        if live { return ("\(remainingMinutes(slot))", "min") }
        let minutes = Int(slot.start.timeIntervalSince(now) / 60)
        if minutes <= 120 { return ("\(max(0, minutes))", "min") }
        return (slot.start.formatted(.dateTime.hour().minute()), "")
    }

    private func remainingMinutes(_ slot: TimeSlot) -> Int {
        max(0, Int(slot.end.timeIntervalSince(now) / 60))
    }

    // MARK: Gribou

    private var gribouContext: Gribou.Context {
        Gribou.Context(
            isPencilDown: false,
            isInClass: currentSlot != nil,
            hasOverdueAssignment: assignments.contains {
                !$0.isDone && ($0.dueAt.map { $0 < now } ?? false)
            },
            streak: player?.streak ?? 0,
            hour: Calendar.current.component(.hour, from: now)
        )
    }

    /// Une phrase qui parle de la journee en cours, pas une formule generique.
    private var gribouSentence: String {
        if let slot = currentSlot, remainingMinutes(slot) > 0 {
            let due = dueCards.count
            return due > 0
                ? "Encore \(remainingMinutes(slot)) min de cours. Après, on descend \(due == 1 ? "la carte" : "les \(due) cartes") ?"
                : "Encore \(remainingMinutes(slot)) min de cours."
        }
        return gribouLine(Gribou.mood(for: gribouContext) ?? .idle)
    }

    private func gribouLine(_ mood: GribouMood) -> String {
        switch mood {
        case .inquiet:   "Un devoir est en retard."
        case .concentre: "Cours en route — je note avec toi."
        case .fier:      "\(player?.streak ?? 0) jours d'affilée. Ça tient."
        case .endormi:   "Il se fait tard. Demain sera plus efficace."
        case .idle:      "Prêt quand tu veux."
        }
    }

    /// L'usure de la mine : dix heures d'écriture, puis elle se retaille au
    /// passage de niveau. La progression est sur le personnage, pas dans une barre —
    /// celle-ci ne fait que chiffrer ce que Gribou montre déjà.
    private var mineWear: Double {
        // Depuis le dernier niveau, pas depuis l'installation : sans ce
        // repere la mine restait usee a 100 % et ne se retaillait jamais.
        let total = pages.reduce(0) { $0 + $1.writingSeconds }
        let since = total - (player?.writingSecondsAtLevel ?? 0)
        return GameValues.mineWear(writingSecondsSinceLevel: since)
    }

    private var mineGauge: some View {
        HStack(spacing: 8) {
            Capsule().fill(K.ink.opacity(0.12))
                .frame(width: 90, height: 6)
                .overlay(alignment: .leading) {
                    Capsule().fill(K.reward).frame(width: 90 * mineWear, height: 6)
                }
            MetaText("mine usée à \(Int(mineWear * 100)) %")
        }
    }

    // MARK: Quêtes

    private var questsColumn: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 6) {
                sectionTitle("Quêtes du jour")
                Spacer(minLength: 0)
                Text("\(questsDone) / 3").font(KFont.mono(11)).foregroundStyle(K.inkSoft)
            }
            ForEach(DailyProgress.dailyQuests, id: \.self) { quest in
                questRow(quest)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Titre de colonne suivi d'un chevron : dans le prototype, chacune ouvre
    /// son ecran.
    private func sectionTitle(_ text: String) -> some View {
        HStack(spacing: 6) {
            DisplayText(text, size: 20)
            ChevronGlyph(pointsRight: true)
                .stroke(K.brand, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .frame(width: 11, height: 11)
        }
    }

    private func questRow(_ quest: DailyProgress.QuestKind) -> some View {
        let done = isDone(quest)
        return HStack(spacing: 12) {
            CheckBadge(kind: .quest, isChecked: done, size: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(quest.title)
                    .font(KFont.body(13, weight: .extraBold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .foregroundStyle(done ? K.inkSoft : K.ink)
                    .strikethrough(done, color: K.inkSoft)
                if !done, quest.target > 1 {
                    MetaText("\(progress(quest)) sur \(quest.target)")
                }
            }
            Spacer(minLength: 0)
            Text("+\(quest.xp)")
                .font(KFont.display(14))
                .foregroundStyle(done ? K.inkSoft : K.brand)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sticker(fill: K.paperAlt, radius: 16, state: done ? .done : .rest)
    }

    private func progress(_ quest: DailyProgress.QuestKind) -> Int {
        guard let activity else { return 0 }
        return DailyActivityStore.progress(quest, in: activity)
    }

    private func isDone(_ quest: DailyProgress.QuestKind) -> Bool {
        progress(quest) >= quest.target
    }

    private var questsDone: Int {
        DailyProgress.dailyQuests.filter(isDone).count
    }

    // MARK: La suite

    private var upcoming: some View {
        VStack(alignment: .leading, spacing: 9) {
            sectionTitle("La suite")
            if nextSlots.isEmpty {
                Text("Plus de cours aujourd'hui.")
                    .font(KFont.body(12, weight: .bold))
                    .foregroundStyle(K.inkSoft)
            }
            ForEach(nextSlots, id: \.id) { slot in
                HStack(spacing: 12) {
                    Text(slot.start.formatted(.dateTime.hour().minute()))
                        .font(KFont.display(17))
                        .foregroundStyle(K.ink)
                        .frame(width: 52, alignment: .leading)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(slot.course?.name ?? slot.summary)
                            .font(KFont.body(13.5, weight: .extraBold))
                            .foregroundStyle(K.ink)
                            .lineLimit(1)
                        if let location = slot.location {
                            Text(location)
                                .font(KFont.body(11, weight: .bold))
                                .foregroundStyle(K.inkSoft)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14).padding(.vertical, 11)
                .frame(maxWidth: .infinity, alignment: .leading)
                .sticker(fill: K.paperAlt, radius: 16, state: .done)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// La ligue demande des amis, qu'aucune donnee ne fournit encore. On dit ce
    /// qui manque plutot que d'inventer un classement.
    private var leagueColumn: some View {
        VStack(alignment: .leading, spacing: 9) {
            sectionTitle("Ligue")
            VStack(alignment: .leading, spacing: 5) {
                Text("Pas encore d'amis")
                    .font(KFont.body(12.5, weight: .extraBold))
                    .foregroundStyle(K.ink)
                Text("La ligue se joue à douze, entre amis ajoutés. Personne ne descend.")
                    .font(KFont.body(11, weight: .bold))
                    .foregroundStyle(K.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .sticker(fill: K.paperAlt, radius: 16, state: .upcoming)
        }
    }

    // MARK: Appel à réviser

    @ViewBuilder
    private func seasonReport(_ season: Season) -> some View {
        SeasonReportView(
            season: season,
            report: SeasonReportStore.report(context, season: season),
            onArchive: {
                let made = SeasonReportStore.report(context, season: season)
                SeasonReportStore.close(season, report: made, context: context)
                reportFor = nil
            },
            onClose: { reportFor = nil }
        )
    }

    /// Le semestre peut-il se clore ? Une fois le partiel passe, et une seule
    /// fois : une saison close ne se propose plus.
    private var closableSeason: Season? {
        guard let season = SeasonStore.current(context), season.closedAt == nil,
              let exam = season.examDate, exam < .now else { return nil }
        return season
    }

    /// Le semestre est fini : on le dit, on ne l'impose pas.
    private func seasonBanner(_ season: Season) -> some View {
        Button { reportFor = season } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Le semestre est terminé")
                        .font(KFont.display(19))
                        .foregroundStyle(K.paperAlt)
                    Text("Ton relevé t'attend : ce que tu as écrit, et ce qu'il t'en reste.")
                        .font(KFont.body(12.5, weight: .bold))
                        .foregroundStyle(K.paperAlt.opacity(0.7))
                }
                Spacer(minLength: 8)
                Text("VOIR LE RELEVÉ")
                    .font(KFont.body(11.5, weight: .extraBold))
                    .tracking(1)
                    .foregroundStyle(K.ink)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(K.reward, in: Capsule())
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(K.ink, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    /// On dit ce qui change, sinon le jeu semble casse.
    private var examBanner: some View {
        HStack(spacing: 14) {
            GribouView(mood: .concentre, size: 46)
            VStack(alignment: .leading, spacing: 3) {
                Text("Mode révision")
                    .font(KFont.display(19))
                    .foregroundStyle(K.paperAlt)
                Text("Sessions de 20 cartes, les plus fragiles d'abord. Ta série est gelée : elle ne monte plus, mais elle ne casse pas.")
                    .font(KFont.body(12.5, weight: .bold))
                    .foregroundStyle(K.paperAlt.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(K.ink, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    @ViewBuilder private var reviewCTA: some View {
        if !dueCards.isEmpty {
            Button { tab = .review } label: {
                HStack {
                    Text("RÉVISER \(dueCards.count) CARTE\(dueCards.count > 1 ? "S" : "")")
                        .font(KFont.display(18))
                        .foregroundStyle(K.ink)
                    Spacer(minLength: 0)
                    Text("+\(GameValues.xpPerCard * dueCards.count) XP")
                        .font(KFont.display(14))
                        .foregroundStyle(K.reward)
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(K.ink, in: Capsule())
                }
                .padding(.horizontal, 20).padding(.vertical, 16)
                .sticker(fill: K.reward, radius: 20)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Données

    private var currentSlot: TimeSlot? {
        let candidates = slots.map { SlotMatcher.Slot(id: $0.id, start: $0.start, end: $0.end) }
        guard let match = SlotMatcher.slotInProgress(at: now, among: candidates) else { return nil }
        return slots.first { $0.id == match.id }
    }

    private var nextSlots: [TimeSlot] {
        slots.filter { $0.start > now }.sorted { $0.start < $1.start }.prefix(3).map { $0 }
    }

    private var dueCards: [Card] { cards.filter { $0.dueAt <= now } }

    /// Les sept jours de la semaine en cours, du lundi au dimanche.
    private var weekMarks: [StreakCard.DayMark] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        guard let monday = calendar.dateInterval(of: .weekOfYear, for: today)?.start else { return [] }
        let labels = ["L", "M", "M", "J", "V", "S", "D"]

        return (0..<7).map { offset in
            let day = calendar.date(byAdding: .day, value: offset, to: monday) ?? monday
            let activity = activities.first { calendar.isDate($0.day, inSameDayAs: day) }
            // Une journee compte des qu'une session y a ete terminee (§9).
            let done = (activity?.cardsReviewed ?? 0) > 0
            return StreakCard.DayMark(
                label: labels[offset],
                done: done,
                isToday: calendar.isDate(day, inSameDayAs: today),
                isFuture: day > today
            )
        }
    }

    private func load() {
        player = try? context.fetch(FetchDescriptor<PlayerState>()).first
        isExamMode = SeasonStore.isExamMode(context)
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-simulateOpenCahier") { simulateOpenTwice() }
        if ProcessInfo.processInfo.arguments.contains("-simulateSeasonClose") {
            let season = SeasonStore.ensure(context)
            let made = SeasonReportStore.report(context, season: season)
            let cahiers = SeasonReportStore.courses(context).count
            SeasonReportStore.close(season, report: made, context: context)
            let after = SeasonReportStore.current(context)
            print("[CLOTURE] avant : \(season.name), \(cahiers) cahier(s) actifs")
            print("[CLOTURE] apres : \(after?.name ?? "aucune") · cahiers actifs=\(SeasonReportStore.courses(context).count)"
                + " · fige=\(Int((season.finalAcquiredPercent ?? 0) * 100))% \(season.finalPagesCount ?? -1) pages"
                + " · close=\(season.closedAt != nil)")
        }
        if ProcessInfo.processInfo.arguments.contains("-simulateSeasonReport") {
            let season = SeasonStore.ensure(context)
            let made = SeasonReportStore.report(context, season: season)
            print("[SAISON] \(made.acquiredPercent)% · \(made.pages) pages · \(made.writingHours) h · "
                + "\(made.cardsReviewed) revues · \(made.goldFiches)/\(made.totalFiches) or · "
                + "mine \(made.mineChanges) · pastilles \(made.states.count)")
            reportFor = season
        }
        #endif
        activity = DailyActivityStore.today(context: context)
    }

    /// Ouvre la page du jour pour ce cours, ou la cree : c'est le geste qu'on
    /// fait en arrivant en amphi.
    #if DEBUG
    /// Rejoue deux appuis sur « Ouvrir le cahier » : ils ne doivent donner
    /// qu'une seule page.
    private func simulateOpenTwice() {
        guard let slot = featuredSlot else { print("[CAHIER] aucun creneau"); return }
        let before = pages.count
        openOrCreatePage(for: slot)
        openOrCreatePage(for: slot)
        print("[CAHIER] pages avant=\(before) apres deux appuis=\((try? context.fetch(FetchDescriptor<Page>()))?.count ?? -1)")
    }
    #endif

    private func openOrCreatePage(for slot: TimeSlot) {
        if let existing = Page.today(for: slot.course, among: pages) {
            onOpenPage(existing)
            return
        }
        let page = Page(createdAt: .now)
        context.insert(page)
        // Hors creneau, l'emploi du temps ne rattache rien. On relie alors la
        // page au cours de la carte : sans ca elle reste orpheline, on ne la
        // retrouve pas, et l'appui suivant en cree encore une.
        if PageAttachment.attach(page, context: context) == nil {
            page.course = slot.course
            page.sessionEnd = slot.end
        }
        page.position = PageOrdering.append(
            to: pages.filter { $0.course?.id == page.course?.id }.map(\.position))
        try? context.save()
        onOpenPage(page)
    }
}

/// La flamme de la série, dessinée.
struct FlameShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addCurve(to: CGPoint(x: rect.maxX, y: rect.midY),
                   control1: CGPoint(x: rect.midX + rect.width * 0.35, y: rect.minY + rect.height * 0.22),
                   control2: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.3))
        p.addCurve(to: CGPoint(x: rect.minX, y: rect.midY),
                   control1: CGPoint(x: rect.maxX, y: rect.maxY),
                   control2: CGPoint(x: rect.minX, y: rect.maxY))
        p.addCurve(to: CGPoint(x: rect.midX, y: rect.minY),
                   control1: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.3),
                   control2: CGPoint(x: rect.midX - rect.width * 0.35, y: rect.minY + rect.height * 0.22))
        return p
    }
}
