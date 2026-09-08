import Foundation
import SwiftData

/// L'unite centrale : une page est simultanement une prise de notes et un noeud
/// de la carte du semestre. Il n'existe pas d'entite « noeud » separee.
@Model public final class Page {
    public var id: UUID = UUID()
    /// Reprise de la 1re ligne reconnue, editable.
    public var title: String = ""
    /// Si true, ne plus jamais l'ecraser (§4).
    public var titleWasEdited: Bool = false
    public var createdAt: Date = Date()
    /// Fin du creneau de cours, si la page est rattachee.
    public var sessionEnd: Date?
    /// Temps reel stylet pose, pas temps d'ecran : c'est lui qui pilote mineWear (§9).
    public var writingSeconds: Int = 0
    /// PKDrawing serialise.
    public var drawing: Data?
    /// Volet Mac ; peut coexister avec le drawing.
    public var markdown: String = ""

    /// Texte reconnu dans le manuscrit, pour la recherche uniquement.
    ///
    /// Il ne remplace jamais le trace et n'est jamais montre a la place des
    /// notes : le §4 interdit de reecrire ce que l'etudiant a ecrit.
    public var recognizedText: String = ""
    /// Si la page annote un PDF depose.
    public var pdfAssetID: UUID?
    public var pdfPageIndex: Int?

    public var course: Course?

    @Relationship(deleteRule: .cascade, inverse: \Card.page)
    public var cards: [Card]? = []

    @Relationship(deleteRule: .cascade, inverse: \Assignment.page)
    public var assignments: [Assignment]? = []

    @Relationship(deleteRule: .cascade, inverse: \AudioRecording.page)
    public var recordings: [AudioRecording]? = []

    public var chapter: Chapter?

    /// Lien chronologique = arete de la carte. Relation reflexive : son inverse
    /// `nextPage` doit exister, sinon supprimer une page casse la chaine.
    @Relationship(inverse: \Page.nextPage)
    public var previousPage: Page?
    public var nextPage: Page?

    public init(title: String = "", createdAt: Date = Date()) {
        self.title = title
        self.createdAt = createdAt
    }
}

public extension Page {
    /// La page du jour pour ce cours, s'il en existe deja une.
    ///
    /// Sans cette recherche, chaque appui sur « Ouvrir le cahier » creait une
    /// page de plus : hors creneau l'emploi du temps ne rattache rien, la page
    /// restait sans matiere, et la fois suivante on ne la retrouvait pas.
    static func today(for course: Course?, among pages: [Page],
                      now: Date = .now, calendar: Calendar = .current) -> Page? {
        guard let course else { return nil }
        return pages.first {
            $0.course?.id == course.id && calendar.isDate($0.createdAt, inSameDayAs: now)
        }
    }
}
