import Foundation
import Testing
@testable import KursoCore

@Suite("Abréviations — §4")
struct AbbreviationsTests {

    @Test("La liste integree n'a aucune clef en double")
    func noDuplicateKeys() {
        // Un litteral de dictionnaire avec doublon plante au premier acces :
        // ce test garde la liste honnete quand elle grandit.
        #expect(Abbreviations.builtin.count >= 120)
    }

    @Test("Les abreviations courantes se resolvent")
    func builtin() {
        #expect(Abbreviations.resolve("pcq")?.long == "parce que")
        #expect(Abbreviations.resolve("thm")?.long == "théorème")
        #expect(Abbreviations.resolve("∀")?.long == "pour tout")
        #expect(Abbreviations.resolve("PCQ")?.source == .builtinList)
    }

    @Test("Un mot ordinaire n'est pas une abreviation")
    func ordinaryWord() {
        #expect(Abbreviations.resolve("théorème") == nil)
        #expect(!Abbreviations.isAbbreviationShaped("théorème"))
        #expect(!Abbreviations.isAbbreviationShaped("12"))
    }

    @Test("Le degre essaie -tion, -sion, -ment")
    func degreeRule() {
        let vocab = ["fonction", "dimension", "groupement"]
        #expect(Abbreviations.byRule("fonc°", vocabulary: vocab) == "fonction")
        #expect(Abbreviations.byRule("dimen°", vocabulary: vocab) == "dimension")
        #expect(Abbreviations.byRule("groupe°", vocabulary: vocab) == "groupement")
    }

    @Test("Le degre ne devine pas hors du vocabulaire")
    func degreeStaysSilent() {
        // Rien dans le vocabulaire : on ne fabrique pas un mot.
        #expect(Abbreviations.byRule("zzz°", vocabulary: ["fonction"]) == nil)
    }

    @Test("Le tiret final cherche un prefixe unique")
    func hyphenRule() {
        // « polygone » ne commence pas par « polyn » : pas d'ambiguite ici.
        #expect(Abbreviations.byRule("polyn-", vocabulary: ["polynome", "polygone"]) == "polynome")
    }

    @Test("Deux suites possibles : on ne tranche pas")
    func hyphenAmbiguous() {
        #expect(Abbreviations.byRule("comp-", vocabulary: ["complexité", "composante"]) == nil)
    }

    @Test("Le squelette de consonnes exige la meme initiale")
    func skeletonNeedsInitial() {
        #expect(Abbreviations.isSkeleton("cplx", of: "complexité"))
        #expect(!Abbreviations.isSkeleton("ts", of: "mathématiques"))
    }

    @Test("Le Mac apprend une paire sans rien demander")
    func learnsFromMac() {
        let pairs = Abbreviations.learnedPairs(
            handwritten: "le cplx° de l'algo est linéaire",
            typed: "la complexité de l'algorithme est linéaire"
        )
        #expect(pairs.contains { $0.short == "cplx°" && $0.long == "complexité" })
        #expect(pairs.allSatisfy { $0.source == .learnedFromMac })
    }

    @Test("On n'apprend pas ce que la liste sait deja")
    func doesNotRelearn() {
        let pairs = Abbreviations.learnedPairs(handwritten: "thm", typed: "théorème")
        #expect(pairs.isEmpty)
    }

    @Test("Ce que l'etudiant a confirme prime sur la liste")
    func userWins() {
        let learned = ["thm": Abbreviations.Resolution(
            short: "thm", long: "thermodynamique", source: .userConfirmed)]
        let resolved = Abbreviations.resolve("thm", learned: learned)
        #expect(resolved?.long == "thermodynamique")
        #expect(resolved?.source == .userConfirmed)
    }

    @Test("On ne demande qu'a partir de trois occurrences")
    func asksAtThree() {
        let twice = "le zbl est la, le zbl revient"
        #expect(Abbreviations.worthAsking(in: twice).isEmpty)
        let thrice = twice + ", encore zbl"
        #expect(Abbreviations.worthAsking(in: thrice) == ["zbl"])
    }

    @Test("La question ne revient jamais")
    func neverAsksTwice() {
        let text = "zbl zbl zbl"
        #expect(Abbreviations.worthAsking(in: text, alreadyAsked: ["zbl"]).isEmpty)
    }

    @Test("On ne demande rien pour ce qu'on sait resoudre")
    func doesNotAskWhatItKnows() {
        #expect(Abbreviations.worthAsking(in: "thm thm thm").isEmpty)
    }
}

@Suite("Abréviations — les deux usages")
struct AbbreviationUseTests {

    @Test("La recherche trouve la forme longue sans toucher la page")
    func searchFindsLongForm() {
        let page = "thm de Rolle, dém au tableau"
        let searchable = Abbreviations.searchableText(page)
        #expect(searchable.contains("théorème"))
        #expect(searchable.contains("démonstration"))
        // La page elle-meme est intacte, en tete du texte augmente.
        #expect(searchable.hasPrefix(page))
    }

    @Test("Un texte sans abreviation n'est pas touche")
    func untouched() {
        let page = "une phrase entièrement écrite"
        #expect(Abbreviations.searchableText(page) == page)
    }

    @Test("Le recto d'une carte se lit en entier")
    func expandedTerm() {
        #expect(Abbreviations.expandedTerm("thm de Rolle") == "théorème de Rolle")
    }
}
