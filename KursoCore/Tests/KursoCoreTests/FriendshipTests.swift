import Testing
import Foundation
@testable import KursoCore

@Suite("Demandes d'ami")
struct FriendshipTests {

    private let mine = "ABC123"

    private func request(_ name: String, code: String,
                         direction: Friendship.Direction,
                         state: Friendship.State = .pending,
                         sentAt: Date = Date()) -> Friendship.Request {
        Friendship.Request(id: "\(name)-\(direction.rawValue)", personID: name, name: name,
                           code: code, direction: direction, state: state, sentAt: sentAt)
    }

    @Test("Un code mal tape ne part pas au serveur")
    func malformed() {
        #expect(Friendship.check(code: "AB", myCode: mine, friends: [], requests: []) == .malformed)
    }

    @Test("On ne s'ajoute pas soi-meme")
    func yourself() {
        #expect(Friendship.check(code: "abc-123", myCode: mine, friends: [], requests: []) == .yourself)
    }

    @Test("Un ami deja la est signale par son nom")
    func alreadyFriends() {
        let friends = [(id: "1", name: "Léa", code: "XYZ789")]
        #expect(Friendship.check(code: "XYZ-789", myCode: mine, friends: friends, requests: []) == .alreadyFriends("Léa"))
    }

    @Test("Une demande deja partie ne repart pas")
    func alreadySent() {
        let sent = [request("Léa", code: "XYZ789", direction: .outgoing)]
        #expect(Friendship.check(code: "XYZ789", myCode: mine, friends: [], requests: sent) == .alreadySent("Léa"))
    }

    @Test("Si l'autre a deja demande, on propose d'accepter plutot que de demander")
    func waitingForYou() {
        let both = [request("Léa", code: "XYZ789", direction: .outgoing),
                    request("Léa", code: "XYZ789", direction: .incoming)]
        #expect(Friendship.check(code: "XYZ789", myCode: mine, friends: [], requests: both) == .waitingForYou("Léa"))
    }

    @Test("Une demande refusee autrefois n'empeche pas de redemander")
    func declinedDoesNotBlock() {
        let old = [request("Léa", code: "XYZ789", direction: .outgoing, state: .declined)]
        #expect(Friendship.check(code: "XYZ789", myCode: mine, friends: [], requests: old) == nil)
    }

    @Test("Un code inconnu passe : seul le serveur sait qui existe")
    func unknownIsServerSide() {
        #expect(Friendship.check(code: "QRS456", myCode: mine, friends: [], requests: []) == nil)
    }

    @Test("Chaque refus porte sa phrase")
    func everyRefusalSpeaks() {
        let all: [Friendship.Refusal] = [.malformed, .yourself, .alreadyFriends("Léa"),
                                         .alreadySent("Léa"), .waitingForYou("Léa")]
        for refusal in all { #expect(!refusal.sentence.isEmpty) }
    }

    @Test("Recues et envoyees ne se melangent pas, les recentes d'abord")
    func sorting() {
        let now = Date()
        let list = [request("Ana", code: "AAA111", direction: .incoming, sentAt: now.addingTimeInterval(-600)),
                    request("Bob", code: "BBB222", direction: .incoming, sentAt: now),
                    request("Cid", code: "CCC333", direction: .outgoing, sentAt: now),
                    request("Dan", code: "DDD444", direction: .incoming, state: .accepted, sentAt: now)]
        #expect(Friendship.incoming(list).map(\.name) == ["Bob", "Ana"])
        #expect(Friendship.outgoing(list).map(\.name) == ["Cid"])
    }

    @Test("Deux personnes qui s'ajoutent en meme temps sont amies tout de suite")
    func mutual() {
        let sent = request("Léa", code: "XYZ789", direction: .outgoing)
        let received = [request("Léa", code: "XYZ789", direction: .incoming)]
        #expect(Friendship.settlesImmediately(sent, against: received))
        #expect(!Friendship.settlesImmediately(sent, against: []))
    }

    @Test("Une demande sans reponse cesse d'attendre au bout d'un mois")
    func stale() {
        let now = Date()
        let old = request("Léa", code: "XYZ789", direction: .outgoing, sentAt: now.addingTimeInterval(-31 * 86_400))
        let fresh = request("Ana", code: "AAA111", direction: .outgoing, sentAt: now.addingTimeInterval(-86_400))
        #expect(Friendship.isStale(old, now: now))
        #expect(!Friendship.isStale(fresh, now: now))
    }
}
