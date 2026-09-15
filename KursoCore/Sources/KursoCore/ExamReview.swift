import Foundation

/// Le retour sur copie (§11, etape 4).
///
/// L'etudiant saisit sa note et coche ce qu'il a rate. Kurso rapproche ces
/// ratés de l'etat de ses pages **la veille de l'examen** — c'est la seule
/// chose qu'aucune autre application ne peut faire, parce qu'elle connait les
/// deux.
///
/// Ce que ca produit n'est pas un bilan : ce sont des reglages pour le
/// semestre suivant. Pas une lecon de morale.
public enum ExamReview {

    /// Ce qu'on a rate, et la page qui le portait.
    public struct Miss: Equatable, Sendable, Identifiable {
        public enum Kind: Sendable, Equatable {
            case exercise
            /// Une question de cours : une definition, pas un resultat.
            case courseQuestion
        }

        public let id: UUID
        public let label: String
        /// Points perdus, toujours positifs.
        public let points: Double
        public let kind: Kind
        /// L'etat de la page la veille de l'examen. Nil si on n'a pas de
        /// photographie — un partiel passe avant que Kurso ne la prenne.
        public let stateAtExam: Freshness.State?
        /// Jours sans revision a la veille de l'examen.
        public let daysSinceReview: Int?
        /// La page qui portait l'exercice, quand il y en a une.
        public let pageID: UUID?

        public init(id: UUID = UUID(), label: String, points: Double, kind: Kind = .exercise,
                    stateAtExam: Freshness.State? = nil, daysSinceReview: Int? = nil,
                    pageID: UUID? = nil) {
            self.id = id
            self.label = label
            self.points = max(0, points)
            self.kind = kind
            self.stateAtExam = stateAtExam
            self.daysSinceReview = daysSinceReview
            self.pageID = pageID
        }

        /// Une page laissee rouge ou jaune la veille.
        public var wasFragile: Bool {
            stateAtExam == .endangered || stateAtExam == .toReview
        }
    }

    /// Un reglage pour le semestre suivant.
    public enum Adjustment: Equatable, Sendable {
        /// Les pages fragiles passent en tete de pile.
        case sickPagesFirst(pages: Int)
        /// Le mode partiel demarre a J-21 au lieu de J-14 (§9).
        case earlierExamMode
        /// Une carte sur cinq demandera une definition mot pour mot.
        case definitionCards

        public var title: String {
            switch self {
            case .sickPagesFirst:  "Les pages malades remontent"
            case .earlierExamMode: "Le mode partiel démarre plus tôt"
            case .definitionCards: "Les questions de cours entrent au jeu"
            }
        }

        public var detail: String {
            switch self {
            case .sickPagesFirst(let pages):
                "\(pages) page\(pages > 1 ? "s" : "") laissée\(pages > 1 ? "s" : "") fragile\(pages > 1 ? "s" : "") passe\(pages > 1 ? "nt" : "") en tête de pile au semestre suivant."
            case .earlierExamMode:
                "À J-\(ExamMode.widenedWindow) au lieu de J-\(ExamMode.window) : \(ExamMode.window) jours n'ont pas suffi à remonter ce qui était rouge."
            case .definitionCards:
                "Une carte sur cinq demandera une définition mot pour mot, pas seulement un résultat."
            }
        }
    }

    public struct Verdict: Equatable, Sendable {
        public var lostPoints: Double
        /// Les ratés qui portaient sur une page laissee fragile.
        public var onFragilePages: Int
        public var adjustments: [Adjustment]

        /// « 6 points » plutot que « 6.0 points ».
        public var lostPointsLabel: String {
            lostPoints == lostPoints.rounded()
                ? String(Int(lostPoints))
                : lostPoints.formatted(.number.precision(.fractionLength(1)))
        }
    }

    /// Il faut au moins deux ratés sur des pages fragiles pour avancer le mode
    /// partiel : un seul peut etre un accident, deux sont une habitude.
    public static let fragileMissesForEarlierMode = 2

    public static func verdict(misses: [Miss], grade: Double, outOf: Double) -> Verdict {
        let lost = max(0, outOf - grade)
        let fragile = misses.filter(\.wasFragile)
        var adjustments: [Adjustment] = []

        if !fragile.isEmpty {
            adjustments.append(.sickPagesFirst(pages: fragile.count))
        }
        if fragile.count >= fragileMissesForEarlierMode {
            adjustments.append(.earlierExamMode)
        }
        if misses.contains(where: { $0.kind == .courseQuestion }) {
            adjustments.append(.definitionCards)
        }

        return Verdict(lostPoints: lost, onFragilePages: fragile.count, adjustments: adjustments)
    }

    /// Le titre de l'ecran.
    public static func headline(_ verdict: Verdict) -> String {
        guard verdict.lostPoints > 0 else { return "Tu n'as rien laissé en route." }
        let points = verdict.lostPointsLabel
        // Accorder a la main : « Où sont parti le 1 point » ne se dit pas.
        guard verdict.lostPoints > 1 else {
            return "Où est parti le \(points) point qui manquait"
        }
        return "Où sont partis les \(points) points qui manquaient"
    }

    /// La phrase de conclusion, sous la liste.
    public static func conclusion(_ verdict: Verdict) -> String? {
        guard verdict.onFragilePages > 0 else { return nil }
        let n = verdict.onFragilePages
        return "\(n) raté\(n > 1 ? "s" : "") venai\(n > 1 ? "en" : "")t de pages laissées fragiles la veille."
    }
}
