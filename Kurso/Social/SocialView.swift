import SwiftUI
import SwiftData
import KursoCore
import KursoModels

/// La ligue, les amis, les classes. Un écran, trois onglets.
///
/// Rien de ce qui est ici n'est nécessaire pour travailler : sans compte et
/// sans amis, Kurso fonctionne entier. C'est pourquoi l'écran ne réclame
/// jamais rien — il explique, et attend.
struct SocialView: View {
    var onClose: () -> Void

    enum Page: String, CaseIterable, Hashable {
        case league, friends, classes

        var title: String {
            switch self {
            case .league:  "LIGUE"
            case .friends: "AMIS"
            case .classes: "CLASSES"
            }
        }
    }

    @Environment(\.modelContext) private var context
    @State private var page: Page = {
        #if DEBUG
        if let index = ProcessInfo.processInfo.arguments.firstIndex(of: "-leaguePage"),
           index + 1 < ProcessInfo.processInfo.arguments.count,
           let requested = Page(rawValue: ProcessInfo.processInfo.arguments[index + 1]) {
            return requested
        }
        #endif
        return .league
    }()
    @State private var store = SocialStore.shared
    @State private var auth = AuthClient.shared

    @Query(sort: \Friend.displayName) private var friends: [Friend]
    @Query private var requests: [FriendRequest]
    @Query(sort: \ClassGroup.joinedAt) private var groups: [ClassGroup]

    @State private var player: PlayerState?
    @State private var typedCode = ""
    @State private var typedGroup = ""
    @State private var newGroupName = ""
    @State private var busy = false
    @State private var message: String?
    @State private var isSigningIn = false
    @State private var now = Date()

    private let tick = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(K.paper)
            .onReceive(tick) { now = $0 }
            .task {
                player = PlayerStore.current(context)
                await store.sync(context)
                store.remember(standings, context: context)
            }
            .sheet(isPresented: $isSigningIn) {
                SignInView {
                    isSigningIn = false
                    Task { await store.sync(context, force: true) }
                }
            }
            .alert("Ligue", isPresented: Binding(
                get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK", role: .cancel) { message = nil }
            } message: {
                Text(message ?? "")
            }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                if !isOpen {
                    signedOutCard
                } else {
                    switch page {
                    case .league:  leagueTab
                    case .friends: friendsTab
                    case .classes: classesTab
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: 980, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: En-tête

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
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
                DisplayText("Ta ligue", size: 30)
                Spacer(minLength: 0)
                if busy || store.phase == .syncing {
                    ProgressView().controlSize(.small)
                }
            }

            if isOpen {
                HStack(spacing: 8) {
                    ForEach(Page.allCases, id: \.self) { item in
                        Button { page = item } label: {
                            Text(item.title)
                                .font(KFont.body(11.5, weight: .extraBold))
                                .tracking(0.8)
                                .foregroundStyle(item == page ? K.paperAlt : K.inkSoft)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 15)
                                .background(item == page ? K.ink : .clear,
                                            in: Capsule())
                                .overlay(Capsule().strokeBorder(
                                    item == page ? .clear : K.ink.opacity(0.22), lineWidth: 2))
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer(minLength: 0)
                    if case .failed(let why) = store.phase {
                        Text(why)
                            .font(KFont.body(11.5, weight: .bold))
                            .foregroundStyle(K.alertBg)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    private var signedOutCard: some View {
        card("PAS DE COMPTE") {
            Text("La ligue a besoin d'un compte : c'est le seul moyen qu'un ami te trouve. Tes cahiers, eux, restent sur cet appareil quoi qu'il arrive.")
                .font(KFont.body(13, weight: .bold))
                .foregroundStyle(K.inkBody)
                .fixedSize(horizontal: false, vertical: true)
            Button("Ouvrir un compte") { isSigningIn = true }
                .buttonStyle(StickerButtonStyle(kind: .primary))
                .frame(maxWidth: 260)
        }
    }

    // MARK: Ligue

    private var leagueTab: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                if standings.count <= 1 {
                    card("PERSONNE ENCORE") {
                        Text("La ligue se joue à douze, entre amis ajoutés. Ajoute quelqu'un avec son code et le tableau s'ouvre.")
                            .font(KFont.body(13, weight: .bold))
                            .foregroundStyle(K.inkBody)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("Ajouter un ami") { page = .friends }
                            .buttonStyle(StickerButtonStyle(kind: .primary))
                            .frame(maxWidth: 240)
                    }
                } else {
                    card("CETTE SEMAINE") {
                        VStack(spacing: 0) {
                            ForEach(Array(standings.enumerated()), id: \.element.id) { index, standing in
                                standingRow(rank: index + 1, standing)
                                if index < standings.count - 1 {
                                    Rectangle().fill(K.hairline).frame(height: 1)
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 12) {
                gradeCard
                rulesCard
            }
            .frame(width: 300)
        }
    }

    private func standingRow(rank: Int, _ standing: LeagueRules.Standing) -> some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(KFont.display(16))
                .foregroundStyle(LeagueRules.isPromoted(rank: rank) ? K.ink : K.inkSoft)
                .frame(width: 26, alignment: .leading)

            Circle()
                .fill(standing.isMe ? K.reward : K.paper)
                .frame(width: 34, height: 34)
                .overlay(Circle().strokeBorder(K.ink, lineWidth: 2.2))
                .overlay(Text(standing.initial)
                    .font(KFont.display(14))
                    .foregroundStyle(K.ink))

            Text(standing.isMe ? "\(standing.name) (toi)" : standing.name)
                .font(KFont.body(13.5, weight: standing.isMe ? .extraBold : .bold))
                .foregroundStyle(K.ink)
                .lineLimit(1)

            Spacer(minLength: 8)

            // La barre des trois premiers : on la voit, on ne la subit pas.
            if LeagueRules.isPromoted(rank: rank) {
                Text("MONTE")
                    .font(KFont.body(9.5, weight: .extraBold))
                    .tracking(0.7)
                    .foregroundStyle(K.paperAlt)
                    .padding(.vertical, 3).padding(.horizontal, 7)
                    .background(K.success, in: Capsule())
            }

            Text("\(standing.weeklyXP) XP")
                .font(KFont.mono(12))
                .foregroundStyle(K.inkBody)
        }
        .padding(.vertical, 9)
        .background(standing.isMe ? K.reward.opacity(0.12) : .clear)
    }

    private var gradeCard: some View {
        card("TA MINE") {
            HStack(spacing: 12) {
                GradeChip(grade: myGrade)
                VStack(alignment: .leading, spacing: 2) {
                    Text(myGrade.label)
                        .font(KFont.display(22))
                        .foregroundStyle(K.ink)
                    Text(myGrade.blurb)
                        .font(KFont.body(11.5, weight: .bold))
                        .foregroundStyle(K.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Text(LeagueRules.summary(rank: myRank, grade: myGrade, count: standings.count))
                .font(KFont.body(12.5, weight: .bold))
                .foregroundStyle(K.inkBody)
                .fixedSize(horizontal: false, vertical: true)
            keyValue("Ferme", closingLine)
        }
    }

    private var rulesCard: some View {
        card("LA RÈGLE") {
            Text("Douze places, uniquement des amis que tu as ajoutés. Les trois premiers montent le dimanche à 20:00.")
                .font(KFont.body(12.5, weight: .bold))
                .foregroundStyle(K.inkBody)
                .fixedSize(horizontal: false, vertical: true)
            Text("Personne ne descend. Jamais.")
                .font(KFont.display(15))
                .foregroundStyle(K.ink)
            Text("Une semaine sans rien faire ne te sort pas de la ligue. Il n'y a aucun classement public, et aucun inconnu ici.")
                .font(KFont.body(11.5, weight: .bold))
                .foregroundStyle(K.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Amis

    private var friendsTab: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                codeCard
                addCard
            }
            .frame(width: 330)

            VStack(alignment: .leading, spacing: 12) {
                if !incoming.isEmpty { incomingCard }
                friendsCard
                if !outgoing.isEmpty { outgoingCard }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var codeCard: some View {
        card("TON CODE") {
            Text(FriendCode.format(myCode))
                .font(KFont.mono(30, weight: .regular))
                .tracking(3)
                .foregroundStyle(K.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(K.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(K.ink, lineWidth: 2.5))
                .textSelection(.enabled)

            Text("Donne-le de vive voix. C'est le seul moyen d'être trouvé : personne ne peut te chercher par ton prénom.")
                .font(KFont.body(11.5, weight: .bold))
                .foregroundStyle(K.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            Button("Copier") { copy(FriendCode.format(myCode)) }
                .buttonStyle(StickerButtonStyle(kind: .secondary))
        }
    }

    private var addCard: some View {
        card("AJOUTER") {
            TextField("Code d'un ami", text: $typedCode)
                .textFieldStyle(.plain)
                .font(KFont.mono(18))
                .tracking(2)
                .foregroundStyle(K.ink)
                .padding(.vertical, 12).padding(.horizontal, 14)
                .background(K.paper, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(K.ink.opacity(0.2), lineWidth: 2))
                .onSubmit(addFriend)
                #if os(iOS)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                #endif

            if let refusal = localRefusal {
                Text(refusal.sentence)
                    .font(KFont.body(11.5, weight: .bold))
                    .foregroundStyle(K.alertBg)
                    .fixedSize(horizontal: false, vertical: true)
            }

            let sendable = !busy && localRefusal == nil && !typedCode.isEmpty
            Button("Envoyer la demande", action: addFriend)
                .buttonStyle(StickerButtonStyle(kind: sendable ? .primary : .secondary))
                .disabled(!sendable)
        }
    }

    private var incomingCard: some View {
        card("ON TE DEMANDE") {
            ForEach(incoming, id: \.id) { request in
                HStack(spacing: 12) {
                    avatar(request.initial, highlighted: true)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(request.displayName)
                            .font(KFont.body(13.5, weight: .extraBold))
                            .foregroundStyle(K.ink)
                        Text(FriendCode.format(request.friendCode))
                            .font(KFont.mono(10.5))
                            .foregroundStyle(K.inkSoft)
                    }
                    Spacer(minLength: 8)
                    Button("Accepter") { answer(request, accept: true) }
                        .buttonStyle(StickerButtonStyle(kind: .confirm, radius: 12))
                        .frame(width: 120)
                    Button("Refuser") { answer(request, accept: false) }
                        .buttonStyle(StickerButtonStyle(kind: .secondary, radius: 12))
                        .frame(width: 110)
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var friendsCard: some View {
        card("TES AMIS") {
            if realFriends.isEmpty {
                Text("Personne encore. Un code, et la ligue s'ouvre.")
                    .font(KFont.body(12.5, weight: .bold))
                    .foregroundStyle(K.inkSoft)
            }
            ForEach(realFriends, id: \.id) { friend in
                HStack(spacing: 12) {
                    avatar(friend.initial, highlighted: false)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(friend.displayName)
                            .font(KFont.body(13.5, weight: .extraBold))
                            .foregroundStyle(K.ink)
                        Text("\(friend.gradeToken) · \(friend.weeklyXP) XP cette semaine")
                            .font(KFont.body(11, weight: .bold))
                            .foregroundStyle(K.inkSoft)
                    }
                    Spacer(minLength: 8)
                    Button("Retirer") { remove(friend) }
                        .buttonStyle(.plain)
                        .font(KFont.body(11.5, weight: .bold))
                        .foregroundStyle(K.alertBg)
                }
                .padding(.vertical, 5)
            }
        }
    }

    private var outgoingCard: some View {
        card("EN ATTENTE") {
            ForEach(outgoing, id: \.id) { request in
                HStack(spacing: 10) {
                    Text(request.displayName)
                        .font(KFont.body(13, weight: .bold))
                        .foregroundStyle(K.inkBody)
                    Spacer(minLength: 8)
                    Text("à lui de répondre")
                        .font(KFont.body(11.5, weight: .bold))
                        .foregroundStyle(K.inkSoft)
                }
                .padding(.vertical, 3)
            }
        }
    }

    // MARK: Classes

    private var classesTab: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                if groups.isEmpty {
                    card("AUCUNE CLASSE") {
                        Text("Un groupe de classe sert à deux choses : ajouter tes camarades sans se dicter douze codes, et savoir à qui demander les notes d'une séance que tu as ratée.")
                            .font(KFont.body(12.5, weight: .bold))
                            .foregroundStyle(K.inkBody)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Il ne partage aucun cours.")
                            .font(KFont.display(14))
                            .foregroundStyle(K.ink)
                    }
                }
                ForEach(groups, id: \.id) { group in groupCard(group) }
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 12) {
                joinCard
                createCard
            }
            .frame(width: 300)
        }
    }

    private func groupCard(_ group: ClassGroup) -> some View {
        card(group.name.uppercased()) {
            HStack(spacing: 10) {
                Text(FriendCode.format(group.joinCode))
                    .font(KFont.mono(17))
                    .tracking(2)
                    .foregroundStyle(K.ink)
                    .padding(.vertical, 8).padding(.horizontal, 12)
                    .background(K.paper, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(K.ink, lineWidth: 2.2))
                Text(Classmates.subtitle(snapshot(group)))
                    .font(KFont.body(12, weight: .bold))
                    .foregroundStyle(K.inkSoft)
                Spacer(minLength: 8)
                Button("Copier") { copy(FriendCode.format(group.joinCode)) }
                    .buttonStyle(.plain)
                    .font(KFont.body(11.5, weight: .bold))
                    .foregroundStyle(K.inkBody)
                Button("Quitter") { leave(group) }
                    .buttonStyle(.plain)
                    .font(KFont.body(11.5, weight: .bold))
                    .foregroundStyle(K.alertBg)
            }

            let mates = (group.members ?? []).sorted { $0.displayName < $1.displayName }
            if !mates.isEmpty {
                HStack(spacing: -6) {
                    ForEach(mates.prefix(12), id: \.id) { mate in
                        avatar(mate.initial, highlighted: false)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var joinCard: some View {
        card("REJOINDRE") {
            TextField("Code du groupe", text: $typedGroup)
                .textFieldStyle(.plain)
                .font(KFont.mono(17))
                .tracking(2)
                .foregroundStyle(K.ink)
                .padding(.vertical, 12).padding(.horizontal, 14)
                .background(K.paper, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(K.ink.opacity(0.2), lineWidth: 2))
                .onSubmit(joinGroup)
                #if os(iOS)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                #endif
            if let refusal = Classmates.checkJoin(code: typedGroup, groups: snapshots), !typedGroup.isEmpty {
                Text(refusal.sentence)
                    .font(KFont.body(11.5, weight: .bold))
                    .foregroundStyle(K.alertBg)
                    .fixedSize(horizontal: false, vertical: true)
            }
            let joinable = !busy && !typedGroup.isEmpty
            Button("Rejoindre", action: joinGroup)
                .buttonStyle(StickerButtonStyle(kind: joinable ? .primary : .secondary))
                .disabled(!joinable)
        }
    }

    private var createCard: some View {
        card("CRÉER") {
            TextField("Nom de la classe", text: $newGroupName)
                .textFieldStyle(.plain)
                .font(KFont.body(14, weight: .bold))
                .foregroundStyle(K.ink)
                .padding(.vertical, 12).padding(.horizontal, 14)
                .background(K.paper, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(K.ink.opacity(0.2), lineWidth: 2))
                .onSubmit(createGroup)
            Text("Tu obtiendras un code à faire circuler. \(Classmates.maxMembers) places, \(Classmates.maxGroups) groupes au maximum.")
                .font(KFont.body(11, weight: .bold))
                .foregroundStyle(K.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            let namable = !busy && !newGroupName.trimmingCharacters(in: .whitespaces).isEmpty
            Button("Créer le groupe", action: createGroup)
                .buttonStyle(StickerButtonStyle(kind: .secondary))
                .disabled(!namable)
        }
    }

    // MARK: Pièces

    private func card(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            Text(title)
                .font(KFont.body(10.5, weight: .extraBold))
                .tracking(1.1)
                .foregroundStyle(K.inkSoft)
            content()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(K.paperAlt, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(K.ink, lineWidth: 2.5))
    }

    private func avatar(_ letter: String, highlighted: Bool) -> some View {
        Circle()
            .fill(highlighted ? K.reward : K.paper)
            .frame(width: 34, height: 34)
            .overlay(Circle().strokeBorder(K.ink, lineWidth: 2.2))
            .overlay(Text(letter).font(KFont.display(14)).foregroundStyle(K.ink))
    }

    private func keyValue(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key)
                .font(KFont.body(12, weight: .bold))
                .foregroundStyle(K.inkBody)
            Spacer(minLength: 8)
            Text(value)
                .font(KFont.mono(11.5))
                .foregroundStyle(K.ink)
        }
    }

    // MARK: Données

    /// Vrai des qu'un compte est ouvert. Le drapeau de mise au point permet
    /// de regarder la mise en page sans reseau ni compte — il ne simule
    /// aucune synchronisation.
    private var isOpen: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-seedLeague") { return true }
        #endif
        return auth.isSignedIn
    }

    private var myCode: String { player?.friendCode ?? store.myCode }

    private var myGrade: LeagueRules.Grade {
        LeagueRules.Grade(rawValue: player?.leagueGrade ?? "HB") ?? .hb
    }

    private var realFriends: [Friend] { friends.filter { !$0.isClassmateOnly } }

    private var incoming: [FriendRequest] {
        requests.filter { $0.directionToken == "incoming" && $0.stateToken == "pending" }
            .sorted { $0.sentAt > $1.sentAt }
    }

    private var outgoing: [FriendRequest] {
        requests.filter { $0.directionToken == "outgoing" && $0.stateToken == "pending" }
            .sorted { $0.sentAt > $1.sentAt }
    }

    private var standings: [LeagueRules.Standing] {
        var rows = realFriends.map {
            LeagueRules.Standing(id: $0.remoteID, name: $0.displayName,
                                 initial: $0.initial, weeklyXP: $0.weeklyXP)
        }
        let name = player?.displayName.isEmpty == false ? player!.displayName : "Toi"
        rows.append(LeagueRules.Standing(id: store.myID ?? "moi", name: name,
                                         weeklyXP: myWeeklyXP, isMe: true))
        return LeagueRules.table(rows)
    }

    private var myWeeklyXP: Int {
        store.weeklyXP(since: LeagueRules.weekStart(for: now), context: context)
    }

    private var myRank: Int? {
        LeagueRules.rank(of: store.myID ?? "moi", in: standings)
    }

    private var closingLine: String {
        let close = LeagueRules.closes(after: now)
        let days = Calendar.current.dateComponents([.day], from: now, to: close).day ?? 0
        return days <= 0 ? "ce soir 20:00" : "dimanche 20:00 · dans \(days) j"
    }

    private var snapshots: [Classmates.Group] { groups.map(snapshot) }

    private func snapshot(_ group: ClassGroup) -> Classmates.Group {
        Classmates.Group(id: group.remoteID, name: group.name, joinCode: group.joinCode,
                         ownerID: group.ownerRemoteID, memberCount: group.memberCount,
                         joinedAt: group.joinedAt)
    }

    /// Ce qu'on peut refuser sans appeler le serveur.
    private var localRefusal: Friendship.Refusal? {
        guard !typedCode.isEmpty else { return nil }
        return Friendship.check(
            code: typedCode,
            myCode: myCode,
            friends: realFriends.map { (id: $0.remoteID, name: $0.displayName, code: $0.friendCode) },
            requests: requests.map {
                Friendship.Request(id: $0.remoteID, personID: $0.personRemoteID,
                                   name: $0.displayName, initial: $0.initial, code: $0.friendCode,
                                   direction: $0.directionToken == "incoming" ? .incoming : .outgoing,
                                   state: .pending, sentAt: $0.sentAt)
            })
    }

    // MARK: Actions

    private func addFriend() {
        guard localRefusal == nil, !busy else { return }
        run {
            let name = try await store.add(code: typedCode, context: context)
            typedCode = ""
            message = "Demande envoyée à \(name)."
        }
    }

    private func answer(_ request: FriendRequest, accept: Bool) {
        run { try await store.answer(request: request, accept: accept, context: context) }
    }

    private func remove(_ friend: Friend) {
        run { try await store.remove(friend: friend, context: context) }
    }

    private func joinGroup() {
        guard Classmates.checkJoin(code: typedGroup, groups: snapshots) == nil, !busy else { return }
        run {
            let name = try await store.joinGroup(code: typedGroup, context: context)
            typedGroup = ""
            message = "Te voilà dans \(name)."
        }
    }

    private func createGroup() {
        let name = newGroupName.trimmingCharacters(in: .whitespaces)
        guard Classmates.checkCreate(name: name, groups: snapshots) == nil, !busy else { return }
        run {
            try await store.createGroup(named: name, context: context)
            newGroupName = ""
        }
    }

    private func leave(_ group: ClassGroup) {
        run { try await store.leave(group: group, context: context) }
    }

    private func run(_ work: @escaping () async throws -> Void) {
        busy = true
        Task {
            do { try await work() }
            catch let failure as SocialClient.Failure { message = failure.errorDescription }
            catch { message = "Ça n'a pas marché. Réessaie." }
            store.remember(standings, context: context)
            busy = false
        }
    }

    private func copy(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
        message = "Copié."
    }
}

/// La pastille de dureté. Plus la mine est tendre, plus elle marque : c'est
/// la seule métaphore de progression du jeu, et elle se voit.
struct GradeChip: View {
    let grade: LeagueRules.Grade

    var body: some View {
        RoundedRectangle(cornerRadius: 11, style: .continuous)
            .fill(fill)
            .frame(width: 46, height: 46)
            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(K.ink, lineWidth: 2.5))
            .overlay(Text(grade.label)
                .font(KFont.display(15))
                .foregroundStyle(grade == .hb ? K.ink : K.paperAlt))
    }

    private var fill: Color {
        switch grade {
        case .hb: K.paper
        case .b2: K.inkSoft
        case .b4: K.brand
        case .b6: K.ink
        }
    }
}
