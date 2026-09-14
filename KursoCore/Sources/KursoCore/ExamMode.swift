import Foundation

/// Le mode partiel (§9).
///
/// A l'approche d'un examen, l'application se tait et se concentre : plus de
/// coffre, plus de ligue, plus d'animation de niveau, et la serie gele — elle
/// n'avance plus, mais elle ne casse pas non plus. On ne culpabilise pas
/// quelqu'un qui revise.
public enum ExamMode {

    /// Jours avant l'examen ou le mode s'active.
    public static let window = 14
    /// Fenetre elargie si le semestre precedent s'est fini avec des pages
    /// rouges : il y a plus a rattraper.
    public static let widenedWindow = 21

    /// Sessions portees a vingt cartes : on revise pour de bon.
    public static let sessionSize = 20
    /// Une fois sur trois, la carte se tire a l'envers — reponse vers question.
    public static let reverseEvery = 3

    public static func isActive(examDate: Date?,
                                now: Date = .now,
                                hadRedPages: Bool = false,
                                calendar: Calendar = .current) -> Bool {
        guard let examDate else { return false }
        let days = calendar.dateComponents([.day], from: now, to: examDate).day ?? .max
        guard days >= 0 else { return false }   // l'examen est passe
        return days <= (hadRedPages ? widenedWindow : window)
    }

    /// Combien de cartes dans une session.
    public static func sessionSize(isExamMode: Bool, ordinary: Int) -> Int {
        isExamMode ? sessionSize : ordinary
    }

    /// Cette carte-la se tire-t-elle a l'envers ?
    ///
    /// Une fois sur trois, pas au hasard : on veut que ce soit reproductible
    /// d'une session a l'autre, sinon la difficulte semble arbitraire.
    public static func isReversed(index: Int, isExamMode: Bool) -> Bool {
        guard isExamMode, index >= 0 else { return false }
        return index % reverseEvery == reverseEvery - 1
    }

    /// Le jeu se met en veille : ni coffre, ni ligue, ni animation de niveau.
    public static func showsGame(isExamMode: Bool) -> Bool { !isExamMode }
}
