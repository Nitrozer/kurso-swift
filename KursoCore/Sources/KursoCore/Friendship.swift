import Foundation

/// Les demandes d'ami : qui a demande quoi a qui, et ce qu'on refuse.
///
/// Une demande est toujours a double sens. Personne n'entre dans la ligue de
/// quelqu'un sans l'avoir accepte — c'est ce qui permet au §9 de promettre
/// « aucun inconnu ».
public enum Friendship {

    public enum State: String, Sendable, Codable, Equatable {
        case pending, accepted, declined
    }

    public enum Direction: String, Sendable, Codable, Equatable {
        /// Recue : quelqu'un vous a ajoute, il attend.
        case incoming
        /// Envoyee : vous attendez.
        case outgoing
    }

    public struct Request: Sendable, Equatable, Identifiable, Codable {
        public var id: String
        public var personID: String
        public var name: String
        public var initial: String
        public var code: String
        public var direction: Direction
        public var state: State
        public var sentAt: Date

        public init(id: String, personID: String, name: String, initial: String = "",
                    code: String = "", direction: Direction, state: State = .pending,
                    sentAt: Date = Date()) {
            self.id = id
            self.personID = personID
            self.name = name
            self.initial = initial.isEmpty ? String(name.prefix(1)).uppercased() : initial
            self.code = code
            self.direction = direction
            self.state = state
            self.sentAt = sentAt
        }
    }

    /// Ce qui empeche d'envoyer. Chaque cas porte sa phrase : un refus muet
    /// laisse croire a une panne.
    public enum Refusal: Equatable, Sendable {
        case malformed
        case yourself
        case alreadyFriends(String)
        case alreadySent(String)
        case waitingForYou(String)

        public var sentence: String {
            switch self {
            case .malformed:
                "Ce code n'a pas la bonne forme. Six signes, comme ABC-123."
            case .yourself:
                "C'est ton propre code."
            case .alreadyFriends(let name):
                "\(name) est déjà dans ta ligue."
            case .alreadySent(let name):
                "Ta demande à \(name) est déjà partie. À lui de répondre."
            case .waitingForYou(let name):
                "\(name) t'a déjà demandé. Accepte, c'est plus court."
            }
        }
    }

    /// Verifie avant d'appeler le serveur. Rend `nil` quand tout va bien.
    ///
    /// Le code inconnu n'est pas teste ici : seul le serveur sait qui existe,
    /// et il repond par `Refusal` cote reseau.
    public static func check(code typed: String,
                             myCode: String,
                             friends: [(id: String, name: String, code: String)],
                             requests: [Request]) -> Refusal? {
        let code = FriendCode.normalise(typed)
        guard FriendCode.isValid(code) else { return .malformed }
        guard code != FriendCode.normalise(myCode) else { return .yourself }
        if let friend = friends.first(where: { FriendCode.normalise($0.code) == code }) {
            return .alreadyFriends(friend.name)
        }
        let pending = requests.filter { $0.state == .pending && FriendCode.normalise($0.code) == code }
        if let received = pending.first(where: { $0.direction == .incoming }) {
            return .waitingForYou(received.name)
        }
        if let sent = pending.first(where: { $0.direction == .outgoing }) {
            return .alreadySent(sent.name)
        }
        return nil
    }

    public static func incoming(_ requests: [Request]) -> [Request] {
        requests
            .filter { $0.direction == .incoming && $0.state == .pending }
            .sorted { $0.sentAt > $1.sentAt }
    }

    public static func outgoing(_ requests: [Request]) -> [Request] {
        requests
            .filter { $0.direction == .outgoing && $0.state == .pending }
            .sorted { $0.sentAt > $1.sentAt }
    }

    /// Deux personnes qui s'ajoutent en meme temps sont amies, point. Leur
    /// faire accepter une demande qu'elles ont deja faite serait absurde.
    public static func settlesImmediately(_ outgoing: Request, against received: [Request]) -> Bool {
        received.contains {
            $0.direction == .incoming && $0.state == .pending && $0.personID == outgoing.personID
        }
    }

    /// Une demande sans reponse ne reste pas a l'ecran indefiniment : passe ce
    /// delai, on cesse de l'afficher plutot que d'entretenir une attente.
    public static let staleAfter: TimeInterval = 30 * 86_400

    public static func isStale(_ request: Request, now: Date = Date()) -> Bool {
        now.timeIntervalSince(request.sentAt) > staleAfter
    }
}
