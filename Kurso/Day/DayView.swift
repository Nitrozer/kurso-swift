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
    @Query(sort: \Page.createdAt, order: .reverse) private var pages: [Page]

    @State private var player: PlayerState?
    @State private var activity: DailyActivity?
    @State private var now = Date()

    /// Le compte a rebours du cours doit avancer sans qu'on touche l'ecran.
    private let tick = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                if let slot = currentSlot { currentCourse(slot) }
                questsCard
                upcoming
                reviewCTA
            }
            .padding(28)
            .frame(maxWidth: 900, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity)
        .background(K.paper)
        .onReceive(tick) { now = $0 }
        .task { load() }
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
            }
        }
    }

    private var dateLine: String {
        let week = Calendar.current.component(.weekOfYear, from: now)
        return "\(now.formatted(.dateTime.weekday(.wide).day().month(.wide))) · semaine \(week)"
    }

    private var greeting: String {
        let streak = player?.streak ?? 0
        return streak > 0 ? "Salut, \(streak) jour\(streak > 1 ? "s" : "") d'affilée." : "Salut."
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

    // MARK: Cours en cours

    private func currentCourse(_ slot: TimeSlot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("EN COURS")
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
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("\(remainingMinutes(slot))").font(KFont.display(48)).foregroundStyle(K.paperAlt)
                    Text("min").font(KFont.body(13, weight: .extraBold)).foregroundStyle(K.paperAlt)
                }
            }

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

    private func timeRange(_ slot: TimeSlot) -> String {
        let start = slot.start.formatted(.dateTime.hour().minute())
        let end = slot.end.formatted(.dateTime.hour().minute())
        guard let teacher = slot.course?.teacher else { return "\(start) → \(end)" }
        return "\(start) → \(end) · \(teacher)"
    }

    private func remainingMinutes(_ slot: TimeSlot) -> Int {
        max(0, Int(slot.end.timeIntervalSince(now) / 60))
    }

    // MARK: Quêtes

    private var questsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                DisplayText("Quêtes du jour", size: 20)
                Spacer(minLength: 0)
                Text("\(questsDone) / 3").font(KFont.mono(12)).foregroundStyle(K.inkSoft)
            }
            ForEach(DailyProgress.dailyQuests, id: \.self) { quest in
                questRow(quest)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sticker(fill: K.paperAlt, radius: 20)
    }

    private func questRow(_ quest: DailyProgress.QuestKind) -> some View {
        let done = isDone(quest)
        return HStack(spacing: 12) {
            CheckBadge(kind: .quest, isChecked: done, size: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(quest.title)
                    .font(KFont.body(13.5, weight: .extraBold))
                    .foregroundStyle(done ? K.inkSoft : K.ink)
                    .strikethrough(done, color: K.inkSoft)
                if !done, quest.target > 1 {
                    MetaText("\(progress(quest)) sur \(quest.target)")
                }
            }
            Spacer(minLength: 0)
            Text("+\(quest.xp)")
                .font(KFont.display(15))
                .foregroundStyle(done ? K.inkSoft : K.ink)
                .padding(.horizontal, 10).padding(.vertical, 3)
                .background(done ? .clear : K.reward, in: Capsule())
                .overlay(Capsule().strokeBorder(done ? K.pendingLine : K.ink, lineWidth: 2.5))
        }
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

    @ViewBuilder private var upcoming: some View {
        if !nextSlots.isEmpty {
            VStack(alignment: .leading, spacing: 11) {
                DisplayText("La suite", size: 20)
                ForEach(nextSlots, id: \.id) { slot in
                    HStack(spacing: 14) {
                        Text(slot.start.formatted(.dateTime.hour().minute()))
                            .font(KFont.mono(12))
                            .foregroundStyle(K.inkSoft)
                            .frame(width: 52, alignment: .leading)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(slot.course?.name ?? slot.summary)
                                .font(KFont.body(13.5, weight: .extraBold))
                                .foregroundStyle(K.ink)
                            if let location = slot.location {
                                MetaText(location)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .sticker(fill: K.paperAlt, radius: 20)
        }
    }

    // MARK: Appel à réviser

    @ViewBuilder private var reviewCTA: some View {
        if !dueCards.isEmpty {
            Button { tab = .review } label: {
                HStack {
                    Text("RÉVISER \(dueCards.count) CARTE\(dueCards.count > 1 ? "S" : "")")
                        .font(KFont.display(18))
                        .foregroundStyle(K.ink)
                    Spacer(minLength: 0)
                    Text("+\(GameValues.xpPerCard * dueCards.count)")
                        .font(KFont.display(15))
                        .foregroundStyle(K.reward)
                        .padding(.horizontal, 10).padding(.vertical, 3)
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

    private func load() {
        player = try? context.fetch(FetchDescriptor<PlayerState>()).first
        activity = DailyActivityStore.today(context: context)
    }

    /// Ouvre la page du jour pour ce cours, ou la cree : c'est le geste qu'on
    /// fait en arrivant en amphi.
    private func openOrCreatePage(for slot: TimeSlot) {
        if let existing = pages.first(where: {
            $0.course?.id == slot.course?.id && Calendar.current.isDateInToday($0.createdAt)
        }) {
            onOpenPage(existing)
            return
        }
        let page = Page(createdAt: .now)
        context.insert(page)
        PageAttachment.attach(page, context: context)
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
