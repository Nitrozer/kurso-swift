import Foundation
import KursoCore

/// Le peu qui passe par le reseau.
///
/// PostgREST en clair, sans SDK : le projet n'a toujours aucune dependance
/// externe. Ce client ne sait pas ce qu'est une page — il ne manipule que des
/// prenoms, des codes, des XP de la semaine et des demandes entre comptes. Le
/// §12 tient ici par construction : il n'existe aucune fonction pour envoyer
/// un cours, et il n'y en aura pas.
@MainActor final class SocialClient {
    static let shared = SocialClient()
    private init() {}

    // MARK: Ce qui circule

    struct Profile: Codable, Sendable, Equatable {
        var id: String
        var displayName: String
        var friendCode: String
        var grade: String
        var weeklyXP: Int
        /// Sans elle, les XP d'un ami qui n'a pas ouvert l'application depuis
        /// lundi compteraient encore pour la semaine en cours.
        var weekStartedAt: Date

        enum CodingKeys: String, CodingKey {
            case id
            case displayName = "display_name"
            case friendCode = "friend_code"
            case grade
            case weeklyXP = "weekly_xp"
            case weekStartedAt = "week_started_at"
        }
    }

    /// Ce que rend la recherche par code. Trois champs : de quoi afficher
    /// « Ajouter Léa ? » et rien de plus.
    struct Person: Codable, Sendable, Equatable {
        var id: String
        var displayName: String
        var grade: String

        enum CodingKeys: String, CodingKey {
            case id
            case displayName = "display_name"
            case grade
        }
    }

    struct Link: Codable, Sendable, Equatable {
        var id: String
        var requester: String
        var addressee: String
        var state: String
        var createdAt: Date

        enum CodingKeys: String, CodingKey {
            case id, requester, addressee, state
            case createdAt = "created_at"
        }
    }

    struct GroupRow: Codable, Sendable, Equatable {
        var id: String
        var name: String
        var joinCode: String
        var owner: String
        var memberCount: Int?

        enum CodingKeys: String, CodingKey {
            case id, name, owner
            case joinCode = "join_code"
            case memberCount = "member_count"
        }
    }

    struct MemberRow: Codable, Sendable, Equatable {
        var groupID: String
        var member: String

        enum CodingKeys: String, CodingKey {
            case groupID = "group_id"
            case member
        }
    }

    struct AskRow: Codable, Sendable, Equatable {
        var id: String
        var asker: String
        var asked: String
        /// Le NOM du cours. Jamais son contenu.
        var courseName: String
        var slotID: String
        var slotStart: Date
        var state: String
        var createdAt: Date

        enum CodingKeys: String, CodingKey {
            case id, asker, asked, state
            case courseName = "course_name"
            case slotID = "slot_id"
            case slotStart = "slot_start"
            case createdAt = "created_at"
        }
    }

    // MARK: Echecs

    enum Failure: LocalizedError, Equatable {
        case offline
        case signedOut
        case notInstalled
        case notFound
        case full
        case rejected(String)

        var errorDescription: String? {
            switch self {
            case .offline:
                "Pas de réseau. La ligue attendra."
            case .signedOut:
                "Connecte-toi pour ouvrir ta ligue."
            case .notInstalled:
                "La ligue n'est pas encore ouverte. Réessaie plus tard."
            case .notFound:
                "Ce code ne correspond à personne."
            case .full:
                "Ce groupe est complet."
            case .rejected(let message):
                message
            }
        }
    }

    // MARK: Profil

    var myID: String? { AuthClient.shared.session?.userID }

    func profile() async throws -> Profile? {
        guard let myID else { throw Failure.signedOut }
        let rows: [Profile] = try await get("kurso_profiles", query: "id=eq.\(myID)&select=*")
        return rows.first
    }

    /// Cree le profil et lui attribue un code. Si le code est deja pris, on
    /// recommence avec le sel suivant — c'est exactement ce pour quoi
    /// `FriendCode.make(from:salt:)` prend un sel.
    func createProfile(name: String) async throws -> Profile {
        guard let myID else { throw Failure.signedOut }
        for salt in 0..<8 {
            let code = FriendCode.make(from: myID, salt: salt)
            do {
                let rows: [Profile] = try await post("kurso_profiles", body: [
                    "id": myID,
                    "display_name": String(name.prefix(40)),
                    "friend_code": code,
                ], returning: true)
                if let first = rows.first { return first }
            } catch Failure.rejected(let message) where message.contains("23505") {
                continue
            }
        }
        throw Failure.rejected("Impossible d'attribuer un code ami.")
    }

    func update(name: String? = nil, grade: String? = nil,
                weeklyXP: Int? = nil, weekStartedAt: Date? = nil) async throws {
        guard let myID else { throw Failure.signedOut }
        var body: [String: Any] = ["updated_at": Self.stamp(Date())]
        if let name { body["display_name"] = String(name.prefix(40)) }
        if let grade { body["grade"] = grade }
        if let weeklyXP { body["weekly_xp"] = max(0, weeklyXP) }
        if let weekStartedAt { body["week_started_at"] = Self.stamp(weekStartedAt) }
        try await patch("kurso_profiles", query: "id=eq.\(myID)", body: body)
    }

    func profiles(ids: [String]) async throws -> [Profile] {
        guard !ids.isEmpty else { return [] }
        let list = ids.map { "\"\($0)\"" }.joined(separator: ",")
        return try await get("kurso_profiles", query: "id=in.(\(list))&select=*")
    }

    // MARK: Amis

    func find(code: String) async throws -> Person {
        let rows: [Person] = try await rpc("kurso_find_by_code", body: ["code": FriendCode.normalise(code)])
        guard let first = rows.first else { throw Failure.notFound }
        return first
    }

    func links() async throws -> [Link] {
        try await get("kurso_friendships", query: "select=*&order=created_at.desc")
    }

    func request(friend id: String) async throws {
        guard let myID else { throw Failure.signedOut }
        try await post("kurso_friendships", body: ["requester": myID, "addressee": id, "state": "pending"])
    }

    func answer(link id: String, accept: Bool) async throws {
        try await patch("kurso_friendships", query: "id=eq.\(id)",
                        body: ["state": accept ? "accepted" : "declined"])
    }

    /// Retirer un ami efface le lien. Il n'en reste rien des deux cotes : la
    /// ligue n'est pas un carnet d'adresses.
    func remove(link id: String) async throws {
        try await delete("kurso_friendships", query: "id=eq.\(id)")
    }

    // MARK: Groupes de classe

    func groups() async throws -> [GroupRow] {
        try await get("kurso_groups", query: "select=*&order=created_at.asc")
    }

    func members(of groupIDs: [String]) async throws -> [MemberRow] {
        guard !groupIDs.isEmpty else { return [] }
        let list = groupIDs.map { "\"\($0)\"" }.joined(separator: ",")
        return try await get("kurso_group_members", query: "group_id=in.(\(list))&select=group_id,member")
    }

    /// Le code du groupe se derive de son identifiant, comme un code ami :
    /// rien a retenir cote serveur, et le meme groupe rend toujours le meme
    /// code.
    func create(group id: UUID, name: String) async throws -> GroupRow {
        guard let myID else { throw Failure.signedOut }
        for salt in 0..<8 {
            let code = Classmates.joinCode(for: id.uuidString, salt: salt)
            do {
                let rows: [GroupRow] = try await post("kurso_groups", body: [
                    "id": id.uuidString.lowercased(),
                    "name": String(name.prefix(40)),
                    "join_code": code,
                    "owner": myID,
                ], returning: true)
                if let first = rows.first { return first }
            } catch Failure.rejected(let message) where message.contains("23505") {
                continue
            }
        }
        throw Failure.rejected("Impossible de créer ce groupe.")
    }

    func join(code: String) async throws -> GroupRow {
        let rows: [GroupRow] = try await rpc("kurso_join_group", body: ["code": FriendCode.normalise(code)])
        guard let first = rows.first else { throw Failure.notFound }
        return first
    }

    func leave(group id: String) async throws {
        guard let myID else { throw Failure.signedOut }
        try await delete("kurso_group_members", query: "group_id=eq.\(id)&member=eq.\(myID)")
    }

    // MARK: Demandes de notes

    func asks() async throws -> [AskRow] {
        try await get("kurso_note_asks", query: "select=*&order=created_at.desc")
    }

    /// Ce qui part : un nom de cours, une date, deux comptes. Les pages, elles,
    /// ne passeront jamais par la.
    func askNotes(to person: String, courseName: String, slotID: String, slotStart: Date) async throws {
        guard let myID else { throw Failure.signedOut }
        try await post("kurso_note_asks", body: [
            "asker": myID,
            "asked": person,
            "course_name": String(courseName.prefix(60)),
            "slot_id": String(slotID.prefix(120)),
            "slot_start": Self.stamp(slotStart),
        ])
    }

    func answer(ask id: String, state: String) async throws {
        try await patch("kurso_note_asks", query: "id=eq.\(id)", body: ["state": state])
    }

    func forget(ask id: String) async throws {
        try await delete("kurso_note_asks", query: "id=eq.\(id)")
    }

    // MARK: Le transport

    private func get<T: Decodable>(_ table: String, query: String) async throws -> T {
        let data = try await send("GET", "rest/v1/\(table)", query: query, body: nil)
        return try Self.decoder.decode(T.self, from: data)
    }

    @discardableResult
    private func post<T: Decodable>(_ table: String, body: [String: Any], returning: Bool = false) async throws -> [T] {
        let data = try await send("POST", "rest/v1/\(table)", query: nil, body: body,
                                  prefer: returning ? "return=representation" : "return=minimal")
        guard returning else { return [] }
        return try Self.decoder.decode([T].self, from: data)
    }

    private func post(_ table: String, body: [String: Any]) async throws {
        let _: [Profile] = try await post(table, body: body, returning: false)
    }

    private func patch(_ table: String, query: String, body: [String: Any]) async throws {
        _ = try await send("PATCH", "rest/v1/\(table)", query: query, body: body, prefer: "return=minimal")
    }

    private func delete(_ table: String, query: String) async throws {
        _ = try await send("DELETE", "rest/v1/\(table)", query: query, body: nil, prefer: "return=minimal")
    }

    private func rpc<T: Decodable>(_ name: String, body: [String: Any]) async throws -> [T] {
        let data = try await send("POST", "rest/v1/rpc/\(name)", query: nil, body: body)
        return try Self.decoder.decode([T].self, from: data)
    }

    /// Un seul endroit ou l'on parle au reseau, et un seul endroit ou l'on
    /// renouvelle le jeton : une session Supabase dure une heure, et elle
    /// expire pendant un cours, pas entre deux lancements.
    private func send(_ method: String, _ path: String, query: String?,
                      body: Any?, prefer: String? = nil, retrying: Bool = false) async throws -> Data {
        guard let session = AuthClient.shared.session else { throw Failure.signedOut }

        var parts = URLComponents(url: SupabaseConfig.url.appending(path: path), resolvingAgainstBaseURL: false)
        parts?.query = query
        guard let url = parts?.url else { throw Failure.rejected("Requête invalide.") }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let prefer { request.setValue(prefer, forHTTPHeaderField: "Prefer") }
        if let body { request.httpBody = try JSONSerialization.data(withJSONObject: body) }
        request.timeoutInterval = 20

        let data: Data, response: URLResponse
        do { (data, response) = try await URLSession.shared.data(for: request) }
        catch { throw Failure.offline }

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401 && !retrying {
            guard await AuthClient.shared.refresh() else { throw Failure.signedOut }
            return try await send(method, path, query: query, body: body, prefer: prefer, retrying: true)
        }
        guard (200..<300).contains(status) else { throw Self.failure(status: status, data: data) }
        return data
    }

    private static func failure(status: Int, data: Data) -> Failure {
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        let code = json["code"] as? String ?? ""
        let message = json["message"] as? String ?? ""

        // Les tables ne sont pas encore posees sur le projet : on le dit
        // franchement plutot que d'afficher une erreur de base de donnees.
        if status == 404 || code == "42P01" || code == "PGRST202" { return .notInstalled }
        switch code {
        case "no_data_found", "P0002": return .notFound
        case "check_violation", "23514": return .full
        // Le message porte le code : `createProfile` s'en sert pour resaler.
        case "23505": return .rejected("23505")
        case "42501", "PGRST301": return .rejected("Tu n'as pas le droit de faire ça.")
        default:
            if message.localizedCaseInsensitiveContains("complet") { return .full }
            if message.localizedCaseInsensitiveContains("introuvable") { return .notFound }
            return .rejected("La ligue n'a pas répondu. Réessaie dans un instant.")
        }
    }

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        // PostgREST rend tantot des secondes fractionnaires, tantot pas.
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            if let date = withFraction.date(from: text) ?? plain.date(from: text) { return date }
            throw DecodingError.dataCorruptedError(in: try decoder.singleValueContainer(),
                                                   debugDescription: "date illisible : \(text)")
        }
        return decoder
    }()

    private static let withFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let plain = ISO8601DateFormatter()

    private static func stamp(_ date: Date) -> String { withFraction.string(from: date) }
}
