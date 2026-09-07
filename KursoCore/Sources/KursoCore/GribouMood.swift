import Foundation

/// L'humeur de Gribou et sa retenue.
///
/// La direction artistique est claire : il n'est pas un logo pose, il est
/// l'indicateur de progression. Elle est tout aussi claire sur ce qu'il ne fait
/// pas — et ce sont ces interdits qui gardent le registre outil.
public enum GribouMood: String, CaseIterable, Sendable {
    case idle       // au repos
    case concentre  // pendant un cours
    case fier       // serie tenue
    case inquiet    // devoir en retard
    case endormi    // apres 23 h

    /// Libelle affiche, accentue.
    public var label: String {
        switch self {
        case .idle:      "au repos"
        case .concentre: "concentré"
        case .fier:      "fier"
        case .inquiet:   "inquiet"
        case .endormi:   "endormi"
        }
    }

    /// Nom du fichier USDZ correspondant.
    public var clipName: String {
        switch self {
        case .idle:      "Gribou_idle"
        case .concentre: "Gribou_concentre"
        case .fier:      "Gribou_fier"
        case .inquiet:   "Gribou_inquiet"
        case .endormi:   "Gribou_endormi"
        }
    }
}

public enum Gribou {

    /// Serie a partir de laquelle il est fier.
    public static let proudStreak = 3
    public static let sleepyHour = 23
    /// « Trois apparitions par session au maximum. »
    public static let maxAppearancesPerSession = 3

    public struct Context: Sendable {
        public var isPencilDown: Bool
        public var isInClass: Bool
        public var hasOverdueAssignment: Bool
        public var streak: Int
        public var hour: Int

        public init(
            isPencilDown: Bool = false,
            isInClass: Bool = false,
            hasOverdueAssignment: Bool = false,
            streak: Int = 0,
            hour: Int = 12
        ) {
            self.isPencilDown = isPencilDown
            self.isInClass = isInClass
            self.hasOverdueAssignment = hasOverdueAssignment
            self.streak = streak
            self.hour = hour
        }
    }

    /// L'humeur a montrer, ou `nil` s'il doit se taire.
    ///
    /// `nil` pendant l'ecriture : « pas de mascotte qui bouge pendant
    /// l'ecriture ». C'est la regle qui protege le registre outil — une
    /// mascotte qui gigote pendant qu'on prend des notes en cours est
    /// insupportable, et c'est ce qui separe Kurso d'une app pour enfants.
    public static func mood(for context: Context) -> GribouMood? {
        guard !context.isPencilDown else { return nil }

        // Un devoir en retard passe avant le reste : c'est le seul etat qui
        // demande une action aujourd'hui.
        if context.hasOverdueAssignment { return .inquiet }
        if context.isInClass { return .concentre }
        if context.hour >= sleepyHour || context.hour < 5 { return .endormi }
        if context.streak >= proudStreak { return .fier }
        return .idle
    }

    /// Reste-t-il de la place dans le budget d'apparitions ?
    public static func canAppear(appearancesSoFar: Int) -> Bool {
        appearancesSoFar < maxAppearancesPerSession
    }
}
