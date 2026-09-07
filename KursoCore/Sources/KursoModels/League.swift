import Foundation
import SwiftData

@Model public final class League {
    public var id: UUID = UUID()
    /// Duretes de mine : "HB" | "2B" | "4B" | "6B".
    public var tier: String = "HB"
    /// Remise a zero le lundi 04:00.
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
    public var displayName: String = ""
    public var initial: String = ""
    /// XP de la SEMAINE seulement (§9).
    public var weeklyXP: Int = 0
    public var isMe: Bool = false
    /// TOUJOURS true : aucun inconnu dans une ligue (§9).
    public var addedByUser: Bool = true

    public var league: League?

    public init(displayName: String = "", initial: String = "", isMe: Bool = false) {
        self.displayName = displayName
        self.initial = initial
        self.isMe = isMe
    }
}
