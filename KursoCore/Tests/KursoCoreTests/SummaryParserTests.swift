import Testing
@testable import KursoCore

@Suite("Decoupage des intitules d'ENT")
struct SummaryParserTests {

    @Test("Matiere, type de seance et enseignant sont separes")
    func fullSummary() {
        let p = SummaryParser.parse("Langues Cours magistral ARTHEY Caroline")
        #expect(p.subject == "Langues")
        #expect(p.sessionType == "Cours Magistral")
        #expect(p.teacher == "ARTHEY Caroline")
    }

    @Test("Une matiere en plusieurs mots reste entiere")
    func multiWordSubject() {
        let p = SummaryParser.parse("Electronique de puissance Cours magistral COLLET Maeva")
        #expect(p.subject == "Electronique de puissance")
    }

    @Test("Un type de seance repete ne vide pas la matiere")
    func repeatedSessionType() {
        // « Travail en Autonomie Travail en Autonomie » : la matiere et le type
        // portent le meme nom. Tout retirer laisserait une chaine vide.
        let p = SummaryParser.parse("Travail en Autonomie Travail en Autonomie")
        #expect(p.subject == "Travail en Autonomie")
    }

    @Test("Le retour a la ligne final de l'export est retire")
    func trailingNewline() {
        let p = SummaryParser.parse("Automatique Cours magistral GIMMIG Matthieu\n")
        #expect(p.subject == "Automatique")
        #expect(p.teacher == "GIMMIG Matthieu")
    }

    @Test("Un intitule sans enseignant ni type reste intact")
    func bareSummary() {
        let p = SummaryParser.parse("Analyse III")
        #expect(p.subject == "Analyse III")
        #expect(p.teacher == nil)
        #expect(p.sessionType == nil)
    }

    @Test("Une abreviation de seance est reconnue")
    func abbreviatedSessionType() {
        #expect(SummaryParser.parse("Reseaux TD DUPONT Marie").subject == "Reseaux")
        #expect(SummaryParser.parse("Reseaux TP").subject == "Reseaux")
    }

    @Test("Un nom compose est bien capture")
    func compoundTeacherName() {
        let p = SummaryParser.parse("Maths CM LE GALL Jean-Pierre")
        #expect(p.subject == "Maths")
        #expect(p.teacher == "LE GALL Jean-Pierre")
    }

    @Test("Un intitule vide ne plante pas")
    func empty() {
        #expect(SummaryParser.parse("").subject == "")
    }
}
