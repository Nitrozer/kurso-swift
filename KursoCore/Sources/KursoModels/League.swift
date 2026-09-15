import Foundation
import SwiftData

@Model public final class League {
    public var id: UUID = UUID()
    /// Duretes de mine : "HB" | "2B" | "4B" | "6B".
    public var tier: String = "HB"
    /// Semaine du dernier releve, qui commence le lundi 04:00 (§9). Elle dit
    /// si le tableau garde en memoire est celui de la semaine qui vient de
    /// fermer — sans quoi on ne saurait pas qui a fini dans les trois.
    public var weekStartsAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \LeagueMember.league)
    public var members: [LeagueMember]? = []

    public init(tier: String = "HB", weekStartsAt: Date = Date()) {
        self.tier = tier
        self.weekStartsAt = weekStartsAt
    }
}

@Model public final class LeagueMember {
    public var id: UUID = UUID()
    /// Identifiant du compte cote serveur, vide pour soi-meme.
    public var remoteID: String = ""
    public var displayName: String = ""
    public var initial: String = ""
    /// XP de la SEMAINE seulement (§9).
    public var weeklyXP: Int = 0
    public var isMe: Bool = false
    /// TOUJOURS true : aucun inconnu dans une ligue (§9).
    public var addedByUser: Bool = true

    /// Durete de mine de la personne, recopiee du serveur.
    public var gradeToken: String = "HB"

    public var league: League?

    public init(remoteID: String = "", displayName: String = "", initial: String = "", isMe: Bool = false) {
        self.remoteID = remoteID
        self.displayName = displayName
        self.initial = initial
        self.isMe = isMe
    }
}
