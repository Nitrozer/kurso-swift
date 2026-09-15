import Foundation
import SwiftData

/// Etat de jeu, instance unique. CloudKit interdisant les contraintes d'unicite,
/// l'unicite est garantie par le code d'acces, pas par le schema.
@Model public final class PlayerState {
    public var id: UUID = UUID()
    public var xp: Int = 0
    public var level: Int = 1
    public var streak: Int = 0
    /// Meilleure serie atteinte, affichee a cote de la serie en cours.
    public var recordStreak: Int = 0
    /// Compteur GLOBAL de 0 a 5, jamais remis a zero par session (§9).
    public var gommesRemaining: Int = 5
    public var lastGommeRegenAt: Date = Date()
    /// Gels : 2 en reserve au maximum, 1 utilisable par semaine.
    public var freezesRemaining: Int = 0
    public var shavings: Int = 0
    /// 0…1, pilote par writingSeconds depuis le dernier niveau.
    public var mineWear: Double = 0
    /// true ⇒ gommes illimitees : le compteur n'est plus decremente.
    public var hasFullVersion: Bool = false

    /// Prenom affiche dans l'en-tete du jour. Vide tant qu'il n'est pas donne :
    /// c'est une preference d'affichage, pas une identite (§12, pas de compte).
    public var displayName: String = ""
    /// L'onboarding ne se rejoue pas.
    public var hasCompletedOnboarding: Bool = false
    /// Dernier jour ou une session a ete terminee. Sans lui, la serie ne
    /// saurait pas distinguer « deja compte » de « jour suivant » (§9).
    public var lastStreakDay: Date?
    /// Mecaniques que Gribou a deja expliquees. Une explication ne se
    /// redonne jamais : c'est ce qui la rend supportable.
    public var seenTips: [String] = []
    /// Couvertures de cahier achetees. Uniquement de l'apparence (§9).
    public var ownedCovers: [String] = []
    /// Secondes d'ecriture totalisees au dernier passage de niveau.
    ///
    /// Sans ce repere, la mine ne se retaillait jamais : elle cumulait toutes
    /// les pages depuis l'installation et restait a 100 % d'usure.
    public var writingSecondsAtLevel: Int = 0

    /// Code ami, attribue par le serveur a la premiere connexion. Vide tant
    /// qu'aucun compte n'est ouvert : la ligue est facultative, l'application
    /// entiere fonctionne sans.
    public var friendCode: String = ""
    /// Durete de mine : "HB" | "2B" | "4B" | "6B" (§9).
    public var leagueGrade: String = "HB"
    /// Derniere fermeture de ligue prise en compte. Sans elle, une promotion
    /// se rejouerait a chaque ouverture de l'ecran.
    public var lastLeagueCloseAt: Date?

    /// Dernier niveau dont le coffre a ete ouvert. Sans lui, le meme coffre
    /// retomberait a chaque lancement de l'application (§9).
    public var lastChestLevel: Int = 1

    public init() {}
}
