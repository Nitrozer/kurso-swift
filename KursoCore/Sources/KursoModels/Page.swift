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
    /// Rang dans son cahier. L'etudiant decide de l'ordre DANS une matiere :
    /// une page ecrite, deux diapos, une photo, puis la suite du cours.
    public var position: Double = 0
    /// Modele de papier : ligné, quadrillé, pointillé ou blanc. Choisi par
    /// l'etudiant — un cours de maths ne s'ecrit pas sur du ligné.
    public var templateRaw: String = "ruled"
    /// Quand le sprint de fin de cours a ete propose pour cette page. On ne
    /// le propose qu'une fois : revenir sur ses notes n'est pas une fin de
    /// seance.
    public var sprintProposedAt: Date?
    /// Quand toutes ses cartes sont devenues sues. Recompense une seule fois :
    /// un noeud maitrise ne se remaitrise pas.
    public var masteredAt: Date?
    /// Photo posee en fond de page. Hors de la base : une image n'a rien a
    /// faire dans un enregistrement SwiftData (§1).
    @Attribute(.externalStorage) public var photo: Data?
    /// Ou la photo est posee, en fractions de la page. Nil : elle occupe
    /// toute la largeur, en haut. C'est ce qui permet de la redimensionner.
    public var photoBox: StoredRect?

    /// Vue pratique sur `photoBox`.
    public var photoRect: CGRect? {
        get { photoBox.map { CGRect(x: $0.x, y: $0.y, width: $0.width, height: $0.height) } }
        set {
            photoBox = newValue.map {
                StoredRect(x: $0.minX, y: $0.minY, width: $0.width, height: $0.height)
            }
        }
    }
    /// L'intercalaire du cahier : « cours », « exercice », « td »,
    /// « correction », ou rien. Liste fermee, definie par `PageTag` : on pose
    /// un intercalaire, on n'en cree jamais (§12).
    public var tagToken: String = ""

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
    /// Le texte de la diapo, quand la page en annote une.
    ///
    /// Lu dans le PDF, jamais reecrit : la moitie des cours sont des diapos
    /// (§11), et sans cela la moitie d'un semestre reste invisible a la
    /// recherche. Distinct de `recognizedText`, qui porte l'ECRITURE relue et
    /// que la reconnaissance reecrit a chaque trait.
    public var slideText: String = ""
    /// Quand la lecture du PDF a ete tentee. Sans cette date, une diapo sans
    /// aucun texte — une image scannee — serait relue a chaque lancement.
    public var slideTextAt: Date?

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

    /// Les images posees sur la page, deplacables et redimensionnables.
    @Relationship(deleteRule: .cascade, inverse: \PageImage.page)
    public var images: [PageImage]? = []

    /// Les blocs de texte tapes au clavier, poses sur la page.
    @Relationship(deleteRule: .cascade, inverse: \PageText.page)
    public var texts: [PageText]? = []

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

public extension Page {
    /// Un PDF depose vaut UNE entree dans les cahiers, pas une par diapo.
    ///
    /// Chaque diapo reste une page a part entiere — elle porte ses propres
    /// annotations — mais les voir toutes alignees donnait l'impression que
    /// l'application fabriquait des notes toute seule.
    static func collapsingSlides(_ pages: [Page]) -> [Page] {
        var kept: [UUID: Page] = [:]
        var out: [Page] = []
        for page in pages {
            guard let asset = page.pdfAssetID else { out.append(page); continue }
            // On garde la PREMIERE diapo, pas celle qui passe en premier dans
            // la requete : c'est elle qu'on ouvre en touchant la vignette.
            if let existing = kept[asset] {
                if (page.pdfPageIndex ?? 0) < (existing.pdfPageIndex ?? 0),
                   let slot = out.firstIndex(where: { $0.id == existing.id }) {
                    out[slot] = page
                    kept[asset] = page
                }
            } else {
                kept[asset] = page
                out.append(page)
            }
        }
        return out
    }
}
