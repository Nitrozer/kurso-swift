import Foundation
import SwiftData

/// L'emploi du temps importe (§6).
///
/// Absent du §1 de PASSATION.md, mais necessaire : les regles de
/// rafraichissement (au plus une fois par 6 h) et de lien expire (apres 5 jours
/// sans reponse valide) demandent de retenir quand on a demande et quand on a
/// obtenu.
@Model public final class Timetable {
    public var id: UUID = UUID()
    /// URL .ics collee par l'utilisateur. Lue localement, jamais envoyee ailleurs.
    public var url: String = ""
    /// Derniere tentative, aboutie ou non.
    public var lastAttemptAt: Date?
    /// Derniere reponse valide. C'est elle qui declenche l'ecran de lien expire.
    public var lastSuccessAt: Date?
    /// L'ecran de lien expire ne s'affiche qu'une fois, sans rien bloquer.
    public var expiryNoticeShown: Bool = false

    public init(url: String = "") { self.url = url }
}

/// Un creneau de cours.
///
/// Stocke plutot que relu a la demande : le rattachement d'une page a son cours
/// doit fonctionner en amphi, ou le hors-ligne est le cas normal.
@Model public final class TimeSlot {
    public var id: UUID = UUID()
    /// Identifiant ICS, pour reconnaitre un creneau deja importe.
    public var icsUID: String = ""
    public var summary: String = ""
    public var location: String?
    public var start: Date = Date()
    public var end: Date = Date()
    public var recurrenceRule: String?

    public var course: Course?

    public init(icsUID: String = "", summary: String = "", start: Date = Date(), end: Date = Date()) {
        self.icsUID = icsUID
        self.summary = summary
        self.start = start
        self.end = end
    }
}
