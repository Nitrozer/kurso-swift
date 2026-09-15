import Foundation
import SwiftData

/// Une personne : un nom, une initiale, un code. Rien d'autre.
///
/// Ce modele ne porte aucune donnee de cours, et n'en portera jamais : le §12
/// interdit qu'une page, une carte ou un enregistrement quitte l'appareil. Ce
/// qui se synchronise d'un ami tient en une ligne — son prenom et ses XP de la
/// semaine, pour que la ligue ait un tableau a afficher.
@Model public final class Friend {
    public var id: UUID = UUID()
    /// Identifiant du compte cote serveur. Seul lien entre cette ligne et
    /// une personne reelle.
    public var remoteID: String = ""
    public var displayName: String = ""
    public var initial: String = ""
    public var friendCode: String = ""
    public var addedAt: Date = Date()
    /// XP de la SEMAINE, recopies du serveur (§9).
    public var weeklyXP: Int = 0
    public var gradeToken: String = "HB"
    public var lastSyncedAt: Date?
    /// Croise dans un groupe de classe sans avoir ete ajoute. On peut lui
    /// demander des notes ; il ne compte pas dans la ligue, qui n'accepte
    /// que des amis ajoutes (§9).
    public var isClassmateOnly: Bool = false

    public var groups: [ClassGroup]? = []

    public init(remoteID: String = "", displayName: String = "", friendCode: String = "") {
        self.remoteID = remoteID
        self.displayName = displayName
        self.initial = String(displayName.prefix(1)).uppercased()
        self.friendCode = friendCode
    }
}

/// Un groupe de classe. Un nom, un code a dicter, des membres.
///
/// Il ne partage pas de cours et ne range rien : l'emploi du temps s'en
/// charge deja (§12). Il sert a savoir a qui demander des notes, et a ajouter
/// ses camarades sans se dicter douze codes.
@Model public final class ClassGroup {
    public var id: UUID = UUID()
    public var remoteID: String = ""
    public var name: String = ""
    public var joinCode: String = ""
    public var ownerRemoteID: String = ""
    public var colorToken: String = "blue"
    public var joinedAt: Date = Date()
    /// Recopie du serveur : le groupe compte des gens dont on n'a pas la fiche.
    public var memberCount: Int = 1

    @Relationship(deleteRule: .nullify, inverse: \Friend.groups)
    public var members: [Friend]? = []

    public init(remoteID: String = "", name: String = "", joinCode: String = "") {
        self.remoteID = remoteID
        self.name = name
        self.joinCode = joinCode
    }
}

/// Une demande d'ami, recue ou envoyee.
@Model public final class FriendRequest {
    public var id: UUID = UUID()
    public var remoteID: String = ""
    public var personRemoteID: String = ""
    public var displayName: String = ""
    public var initial: String = ""
    public var friendCode: String = ""
    /// "incoming" | "outgoing"
    public var directionToken: String = "incoming"
    /// "pending" | "accepted" | "declined"
    public var stateToken: String = "pending"
    public var sentAt: Date = Date()

    public init(remoteID: String = "", personRemoteID: String = "",
                displayName: String = "", directionToken: String = "incoming") {
        self.remoteID = remoteID
        self.personRemoteID = personRemoteID
        self.displayName = displayName
        self.initial = String(displayName.prefix(1)).uppercased()
        self.directionToken = directionToken
    }
}

/// Une demande de notes pour une seance ou l'on n'etait pas.
///
/// Ce qui circule par le serveur tient dans cette ligne : un nom de cours, un
/// jour, deux comptes. **Les pages ne sont pas la** — celui qui accepte envoie
/// un fichier directement a l'autre appareil. Le §12 ne bouge pas.
@Model public final class NoteAsk {
    public var id: UUID = UUID()
    public var remoteID: String = ""
    /// "incoming" | "outgoing"
    public var directionToken: String = "outgoing"
    public var personRemoteID: String = ""
    public var displayName: String = ""
    public var courseName: String = ""
    /// Identifiant du creneau, pour ne pas reproposer la meme seance.
    public var slotID: String = ""
    public var slotStart: Date = Date()
    /// "pending" | "accepted" | "declined" | "handed" — `handed` veut dire que
    /// le fichier est parti par AirDrop.
    public var stateToken: String = "pending"
    public var createdAt: Date = Date()

    public init(remoteID: String = "", directionToken: String = "outgoing",
                personRemoteID: String = "", displayName: String = "",
                courseName: String = "", slotID: String = "", slotStart: Date = Date()) {
        self.remoteID = remoteID
        self.directionToken = directionToken
        self.personRemoteID = personRemoteID
        self.displayName = displayName
        self.courseName = courseName
        self.slotID = slotID
        self.slotStart = slotStart
    }
}

/// Une seance qu'on a decide de ne pas reclamer. On ne repropose pas.
@Model public final class DismissedSlot {
    public var id: UUID = UUID()
    public var slotID: String = ""
    public var dismissedAt: Date = Date()

    public init(slotID: String = "") { self.slotID = slotID }
}
