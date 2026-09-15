import Foundation
import Observation
import SwiftData
import KursoCore
import KursoModels

/// Ce qui relie la ligue a l'application : un aller-retour reseau, et la mise
/// a jour des modeles locaux.
///
/// L'application entiere fonctionne sans. Sans compte, sans reseau, sans amis,
/// rien ne se bloque : la ligue est un supplement, pas une condition. C'est
/// pour cela que chaque echec se range dans `phase` et ne remonte jamais en
/// alerte au milieu d'un cours.
@MainActor @Observable final class SocialStore {
    static let shared = SocialStore()
    private init() {}

    enum Phase: Equatable {
        case idle
        case syncing
        case ready
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    private(set) var lastSyncedAt: Date?
    private(set) var myCode: String = ""

    var isSignedIn: Bool { AuthClient.shared.isSignedIn }
    /// L'identifiant du compte, dont les tableaux ont besoin pour se
    /// reconnaitre eux-memes dans un classement.
    var myID: String? { AuthClient.shared.session?.userID }
    private var client: SocialClient { .shared }

    /// Un aller-retour par minute au maximum : la ligue n'a aucune raison
    /// d'etre plus fraiche que ca, et le reseau d'un amphi non plus.
    private static let cooldown: TimeInterval = 60

    // MARK: L'aller-retour

    func sync(_ context: ModelContext, force: Bool = false) async {
        guard isSignedIn else {
            phase = .idle
            return
        }
        if !force, let last = lastSyncedAt, Date().timeIntervalSince(last) < Self.cooldown { return }
        guard phase != .syncing else { return }
        phase = .syncing

        do {
            let player = PlayerStore.current(context)
            let profile = try await profile(for: player)
            player.friendCode = profile.friendCode
            myCode = profile.friendCode

            try await pushMyWeek(player: player, profile: profile, context: context)
            let people = try await pullLinks(context: context, player: player)
            try await pullGroups(context: context, known: people)
            try await pullAsks(context: context)

            settleLeagueClose(player: player, context: context)
            try? context.save()

            lastSyncedAt = Date()
            phase = .ready
        } catch let failure as SocialClient.Failure {
            phase = .failed(failure.errorDescription ?? "La ligue n'a pas répondu.")
        } catch {
            phase = .failed("La ligue n'a pas répondu.")
        }
    }

    private func profile(for player: PlayerState) async throws -> SocialClient.Profile {
        if let existing = try await client.profile() { return existing }
        let name = player.displayName.isEmpty ? "Sans nom" : player.displayName
        return try await client.createProfile(name: name)
    }

    /// Declare les XP de la semaine. Ils sont gagnes hors ligne : le serveur
    /// ne peut que les recopier. Une ligue de douze amis sans classement
    /// public ne justifie pas d'inventer une verification.
    private func pushMyWeek(player: PlayerState, profile: SocialClient.Profile,
                            context: ModelContext) async throws {
        let start = LeagueRules.weekStart(for: .now)
        let mine = weeklyXP(since: start, context: context)
        let name = player.displayName.isEmpty ? "Sans nom" : player.displayName
        guard mine != profile.weeklyXP
                || name != profile.displayName
                || player.leagueGrade != profile.grade
                || profile.weekStartedAt < start else { return }
        try await client.update(name: name, grade: player.leagueGrade,
                                weeklyXP: mine, weekStartedAt: start)
    }

    /// Somme des XP depuis le lundi. Rien a remettre a zero : une remise a
    /// zero ratee ferait disparaitre une semaine de travail, alors qu'une
    /// somme sur une fenetre ne se trompe jamais.
    ///
    /// `DailyActivity` compte par journee entiere : les XP du lundi entre
    /// minuit et 04:00 tombent donc du bon cote de justesse. On l'assume —
    /// decouper une journee pour quatre heures couterait plus cher que
    /// l'erreur qu'on evite.
    func weeklyXP(since start: Date, context: ModelContext, calendar: Calendar = .current) -> Int {
        let firstDay = calendar.startOfDay(for: start)
        let days = (try? context.fetch(FetchDescriptor<DailyActivity>())) ?? []
        return days.filter { $0.day >= firstDay }.reduce(0) { $0 + $1.xpEarned }
    }

    // MARK: Amis et demandes

    private func pullLinks(context: ModelContext, player: PlayerState) async throws -> [String: SocialClient.Profile] {
        guard let myID = client.myID else { return [:] }
        let links = try await client.links()
        let others = Set(links.map { $0.requester == myID ? $0.addressee : $0.requester })
        let people = try await client.profiles(ids: Array(others))
        let byID = Dictionary(uniqueKeysWithValues: people.map { ($0.id, $0) })
        let weekStart = LeagueRules.weekStart(for: .now)

        // Amis acceptes.
        let accepted = links.filter { $0.state == "accepted" }
        var friends = (try? context.fetch(FetchDescriptor<Friend>())) ?? []
        let keptIDs = Set(accepted.map { $0.requester == myID ? $0.addressee : $0.requester })

        for friend in friends where !friend.isClassmateOnly && !keptIDs.contains(friend.remoteID) {
            context.delete(friend)
        }
        friends = friends.filter { keptIDs.contains($0.remoteID) || $0.isClassmateOnly }

        for link in accepted {
            let otherID = link.requester == myID ? link.addressee : link.requester
            guard let person = byID[otherID] else { continue }
            let row = friends.first { $0.remoteID == otherID } ?? {
                let made = Friend(remoteID: otherID)
                context.insert(made)
                friends.append(made)
                return made
            }()
            row.displayName = person.displayName
            row.initial = String(person.displayName.prefix(1)).uppercased()
            row.friendCode = person.friendCode
            row.gradeToken = person.grade
            // Les XP d'un ami qui n'a pas ouvert l'application depuis lundi
            // appartiennent a la semaine d'avant : ils ne comptent pas.
            row.weeklyXP = person.weekStartedAt >= weekStart ? person.weeklyXP : 0
            row.isClassmateOnly = false
            row.lastSyncedAt = .now
            row.addedAt = min(row.addedAt, link.createdAt)
        }

        // Demandes en attente, recues comme envoyees.
        let pending = links.filter { $0.state == "pending" }
        let existing = (try? context.fetch(FetchDescriptor<FriendRequest>())) ?? []
        let pendingIDs = Set(pending.map(\.id))
        for request in existing where !pendingIDs.contains(request.remoteID) {
            context.delete(request)
        }
        for link in pending {
            let incoming = link.addressee == myID
            let otherID = incoming ? link.requester : link.addressee
            guard let person = byID[otherID] else { continue }
            let row = existing.first { $0.remoteID == link.id } ?? {
                let made = FriendRequest(remoteID: link.id)
                context.insert(made)
                return made
            }()
            row.personRemoteID = otherID
            row.displayName = person.displayName
            row.initial = String(person.displayName.prefix(1)).uppercased()
            row.friendCode = person.friendCode
            row.directionToken = incoming ? "incoming" : "outgoing"
            row.stateToken = "pending"
            row.sentAt = link.createdAt
        }
        return byID
    }

    // MARK: Groupes de classe

    private func pullGroups(context: ModelContext, known: [String: SocialClient.Profile]) async throws {
        guard let myID = client.myID else { return }
        let remote = try await client.groups()
        var local = (try? context.fetch(FetchDescriptor<ClassGroup>())) ?? []
        let keptIDs = Set(remote.map(\.id))
        for group in local where !keptIDs.contains(group.remoteID) { context.delete(group) }
        local = local.filter { keptIDs.contains($0.remoteID) }

        let memberships = try await client.members(of: remote.map(\.id))
        let strangers = Set(memberships.map(\.member)).subtracting(known.keys).subtracting([myID])
        let extra = try await client.profiles(ids: Array(strangers))
        var people = known
        for person in extra { people[person.id] = person }

        var friends = (try? context.fetch(FetchDescriptor<Friend>())) ?? []

        for row in remote {
            let group = local.first { $0.remoteID == row.id } ?? {
                let made = ClassGroup(remoteID: row.id)
                context.insert(made)
                local.append(made)
                return made
            }()
            group.name = row.name
            group.joinCode = row.joinCode
            group.ownerRemoteID = row.owner
            let members = memberships.filter { $0.groupID == row.id }.map(\.member)
            group.memberCount = members.count

            group.members = members.compactMap { memberID -> Friend? in
                guard memberID != myID, let person = people[memberID] else { return nil }
                let mate = friends.first { $0.remoteID == memberID } ?? {
                    let made = Friend(remoteID: memberID)
                    made.isClassmateOnly = true
                    context.insert(made)
                    friends.append(made)
                    return made
                }()
                mate.displayName = person.displayName
                mate.initial = String(person.displayName.prefix(1)).uppercased()
                mate.friendCode = person.friendCode
                return mate
            }
        }

        // Un camarade qui n'est plus dans aucun groupe et qui n'est pas un ami
        // n'a plus de raison d'etre retenu.
        for mate in friends where mate.isClassmateOnly && (mate.groups?.isEmpty ?? true) {
            context.delete(mate)
        }
    }

    // MARK: Demandes de notes

    private func pullAsks(context: ModelContext) async throws {
        guard let myID = client.myID else { return }
        let remote = try await client.asks()
        let local = (try? context.fetch(FetchDescriptor<NoteAsk>())) ?? []
        let friends = (try? context.fetch(FetchDescriptor<Friend>())) ?? []
        let keptIDs = Set(remote.map(\.id))
        for ask in local where !keptIDs.contains(ask.remoteID) { context.delete(ask) }

        for row in remote {
            let incoming = row.asked == myID
            let otherID = incoming ? row.asker : row.asked
            let ask = local.first { $0.remoteID == row.id } ?? {
                let made = NoteAsk(remoteID: row.id)
                context.insert(made)
                return made
            }()
            ask.directionToken = incoming ? "incoming" : "outgoing"
            ask.personRemoteID = otherID
            ask.displayName = friends.first { $0.remoteID == otherID }?.displayName ?? "Quelqu'un de ta classe"
            ask.courseName = row.courseName
            ask.slotID = row.slotID
            ask.slotStart = row.slotStart
            ask.stateToken = row.state
            ask.createdAt = row.createdAt
        }
    }

    // MARK: La fermeture du dimanche

    /// Applique la promotion si une fermeture est passee sans qu'on soit la.
    ///
    /// Le tableau retenu sert de preuve : s'il date de la semaine qui vient de
    /// fermer, on sait qui a fini dans les trois. Sinon on ne promeut personne
    /// — et comme personne ne descend jamais (§9), ne rien faire est toujours
    /// un resultat juste.
    private func settleLeagueClose(player: PlayerState, context: ModelContext) {
        let now = Date()
        let lastClose = LeagueRules.closes(after: now).addingTimeInterval(-7 * 86_400)
        guard lastClose <= now else { return }
        if let seen = player.lastLeagueCloseAt, seen >= lastClose { return }

        let cached = league(context)
        let closingWeek = LeagueRules.weekStart(for: lastClose)
        defer {
            player.lastLeagueCloseAt = lastClose
            cached.weekStartsAt = LeagueRules.weekStart(for: now)
            cached.tier = player.leagueGrade
        }
        guard cached.weekStartsAt == closingWeek else { return }

        let standings = (cached.members ?? []).map {
            LeagueRules.Standing(id: $0.remoteID, name: $0.displayName,
                                 initial: $0.initial, weeklyXP: $0.weeklyXP, isMe: $0.isMe)
        }
        guard standings.count > 1,
              let mine = standings.first(where: \.isMe),
              let rank = LeagueRules.rank(of: mine.id, in: standings),
              let grade = LeagueRules.Grade(rawValue: player.leagueGrade)
        else { return }

        if case .promoted(let next) = LeagueRules.outcome(grade: grade, rank: rank) {
            player.leagueGrade = next.rawValue
            promotion = next
        }
    }

    /// La derniere promotion obtenue, a annoncer une fois puis a oublier.
    var promotion: LeagueRules.Grade?

    private func league(_ context: ModelContext) -> League {
        if let existing = try? context.fetch(FetchDescriptor<League>()).first { return existing }
        let made = League()
        context.insert(made)
        return made
    }

    /// Retient le tableau du moment, pour que la fermeture de dimanche ait
    /// quelque chose a lire meme si l'application n'est pas ouverte ce soir-la.
    func remember(_ standings: [LeagueRules.Standing], context: ModelContext) {
        let cached = league(context)
        for member in cached.members ?? [] { context.delete(member) }
        cached.members = standings.map { standing in
            let member = LeagueMember(remoteID: standing.id, displayName: standing.name,
                                      initial: standing.initial, isMe: standing.isMe)
            member.weeklyXP = standing.weeklyXP
            context.insert(member)
            return member
        }
        cached.weekStartsAt = LeagueRules.weekStart(for: .now)
        try? context.save()
    }

    // MARK: Ce que l'ecran demande

    func add(code typed: String, context: ModelContext) async throws -> String {
        let person = try await client.find(code: typed)
        try await client.request(friend: person.id)
        await sync(context, force: true)
        return person.displayName
    }

    func answer(request: FriendRequest, accept: Bool, context: ModelContext) async throws {
        try await client.answer(link: request.remoteID, accept: accept)
        await sync(context, force: true)
    }

    func remove(friend: Friend, context: ModelContext) async throws {
        guard let myID = client.myID else { throw SocialClient.Failure.signedOut }
        let links = try await client.links()
        let link = links.first {
            $0.state == "accepted"
                && (($0.requester == myID && $0.addressee == friend.remoteID)
                    || ($0.addressee == myID && $0.requester == friend.remoteID))
        }
        if let link { try await client.remove(link: link.id) }
        await sync(context, force: true)
    }

    func createGroup(named name: String, context: ModelContext) async throws {
        _ = try await client.create(group: UUID(), name: name)
        await sync(context, force: true)
    }

    func joinGroup(code typed: String, context: ModelContext) async throws -> String {
        let group = try await client.join(code: typed)
        await sync(context, force: true)
        return group.name
    }

    func leave(group: ClassGroup, context: ModelContext) async throws {
        try await client.leave(group: group.remoteID)
        await sync(context, force: true)
    }

    func askNotes(to person: Friend, miss: MissedClass.Miss, context: ModelContext) async throws {
        try await client.askNotes(to: person.remoteID, courseName: miss.courseName,
                                  slotID: miss.id, slotStart: miss.start)
        await sync(context, force: true)
    }

    func answer(ask: NoteAsk, state: String, context: ModelContext) async throws {
        try await client.answer(ask: ask.remoteID, state: state)
        ask.stateToken = state
        try? context.save()
    }

    func forget(ask: NoteAsk, context: ModelContext) async throws {
        try await client.forget(ask: ask.remoteID)
        context.delete(ask)
        try? context.save()
    }
}
