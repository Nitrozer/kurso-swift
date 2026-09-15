import Foundation

/// Les groupes de classe : un nom, un code, et les gens qui l'ont tape.
///
/// Un groupe ne partage aucun cours. Il sert a deux choses seulement : savoir
/// a qui demander les notes d'une seance manquee, et ajouter ses camarades
/// sans se dicter douze codes un par un.
public enum Classmates {

    /// Une classe, pas un reseau. Au-dela, ce n'est plus un groupe ou l'on
    /// se connait.
    public static let maxMembers = 40

    /// Trois groupes suffisent : la classe, le TD, l'option.
    public static let maxGroups = 3

    public struct Group: Sendable, Equatable, Identifiable, Codable {
        public var id: String
        public var name: String
        public var joinCode: String
        public var ownerID: String
        public var memberCount: Int
        public var joinedAt: Date

        public init(id: String, name: String, joinCode: String, ownerID: String = "",
                    memberCount: Int = 1, joinedAt: Date = Date()) {
            self.id = id
            self.name = name
            self.joinCode = joinCode
            self.ownerID = ownerID
            self.memberCount = memberCount
            self.joinedAt = joinedAt
        }
    }

    public enum Refusal: Equatable, Sendable {
        case malformed
        case alreadyIn(String)
        case full(String)
        case tooManyGroups
        case namelessGroup

        public var sentence: String {
            switch self {
            case .malformed:
                "Ce code n'a pas la bonne forme. Six signes, comme ABC-123."
            case .alreadyIn(let name):
                "Tu es déjà dans \(name)."
            case .full(let name):
                "\(name) est complet : \(Classmates.maxMembers) places."
            case .tooManyGroups:
                "Trois groupes au maximum. Quitte-en un pour en rejoindre un autre."
            case .namelessGroup:
                "Donne un nom à ce groupe."
            }
        }
    }

    public static func checkJoin(code typed: String, groups: [Group]) -> Refusal? {
        let code = FriendCode.normalise(typed)
        guard FriendCode.isValid(code) else { return .malformed }
        if let existing = groups.first(where: { FriendCode.normalise($0.joinCode) == code }) {
            return .alreadyIn(existing.name)
        }
        guard groups.count < maxGroups else { return .tooManyGroups }
        return nil
    }

    public static func checkCreate(name: String, groups: [Group]) -> Refusal? {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .namelessGroup }
        guard groups.count < maxGroups else { return .tooManyGroups }
        return nil
    }

    /// Le code d'un groupe se fabrique comme un code ami, a partir de son
    /// identifiant : rien a stocker, et le meme groupe rend toujours le meme
    /// code — celui qui l'a note sur un coin de cahier peut le retaper.
    public static func joinCode(for groupID: String, salt: Int = 0) -> String {
        FriendCode.make(from: "groupe:\(groupID)", salt: salt)
    }

    /// Ce qu'on affiche sous le nom du groupe.
    public static func subtitle(_ group: Group) -> String {
        switch group.memberCount {
        case ...1: "Toi seul pour l'instant"
        case 2: "Toi et une autre personne"
        default: "\(group.memberCount) personnes"
        }
    }
}
