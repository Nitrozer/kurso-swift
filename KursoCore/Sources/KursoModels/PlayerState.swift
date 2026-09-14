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
    /// Couvertures de cahier achetees. Uniquement de l'apparence (§9).
    public var ownedCovers: [String] = []
    /// Dernier niveau dont le coffre a ete ouvert. Sans lui, le meme coffre
    /// retomberait a chaque lancement de l'application (§9).
    public var lastChestLevel: Int = 1

    public init() {}
}
