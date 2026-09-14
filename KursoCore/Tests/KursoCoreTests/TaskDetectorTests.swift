import Testing
import Foundation
@testable import KursoCore

@Suite("Detection des devoirs — §5")
struct TaskDetectorTests {

    var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone.current
        return c
    }

    func hour(_ date: Date) -> Int { calendar.component(.hour, from: date) }

    @Test("Une ligne avec marqueur et date devient une proposition")
    func detectsTask() {
        let found = TaskDetector.detect(in: "DM d'automatique à rendre pour le 15 octobre")
        #expect(found.count == 1)
    }

    @Test("Une ligne sans marqueur d'obligation est ignoree")
    func requiresMarker() {
        // Une date seule ne fait pas un devoir : un cours a une date aussi.
        #expect(TaskDetector.detect(in: "chapitre 3 vu le 15 octobre").isEmpty)
    }

    @Test("Une ligne sans date est ignoree")
    func requiresDate() {
        #expect(TaskDetector.detect(in: "il faut reviser le DM").isEmpty)
    }

    @Test("Sans heure indiquee, l'echeance tombe a 18:00")
    func defaultsToSixPM() {
        let found = TaskDetector.detect(in: "exposé à rendre pour le 15 octobre")
        #expect(hour(found[0].dueAt) == 18)
    }

    @Test("Une heure explicite est respectee")
    func keepsExplicitTime() {
        // Sans ce test, la regle des 18:00 ecraserait l'heure donnee.
        let found = TaskDetector.detect(in: "TP à rendre le 3 novembre à 14h")
        #expect(hour(found[0].dueAt) == 14)
    }

    @Test("Le titre est debarrasse du marqueur et de la date")
    func cleansTitle() {
        let found = TaskDetector.detect(in: "DM d'automatique à rendre pour le 15 octobre")
        #expect(found[0].title == "DM d'automatique")
    }

    @Test("Le marqueur declencheur est conserve")
    func keepsMarker() {
        let found = TaskDetector.detect(in: "exposé pour demain")
        #expect(found[0].marker == "pour demain")
    }

    @Test("Un marqueur desactive ne propose plus rien")
    func disabledMarkerIsSilent() {
        // Trois refus sur le meme marqueur et il se tait, sans reglage ni message.
        let text = "TD à rendre pour le 15 octobre"
        #expect(TaskDetector.detect(in: text).isEmpty == false)
        #expect(TaskDetector.detect(in: text, disabledMarkers: ["à rendre"]).isEmpty)
    }

    @Test("Chaque ligne est analysee separement")
    func perLine() {
        let text = """
        cours sur les graphes
        DM à rendre pour le 15 octobre
        exposé pour demain
        """
        let found = TaskDetector.detect(in: text)
        #expect(found.count == 2)
        #expect(found.map(\.lineIndex) == [1, 2])
    }

    @Test("Une ligne reduite au marqueur et a la date ne propose rien")
    func emptyTitleIsSkipped() {
        // Sans titre, la proposition n'aurait rien a montrer en marge.
        #expect(TaskDetector.detect(in: "à rendre le 15 octobre").isEmpty)
    }
}

@Suite("Detection — phrases reelles d'etudiant")
struct TaskDetectorRealLifeTests {
    private let cal = Calendar(identifier: .gregorian)

    private func titles(_ text: String) -> [String] {
        TaskDetector.detect(in: text, calendar: cal).map(\.title)
    }

    @Test("« TD à rendre pour jeudi 30 »")
    func tdARendre() {
        #expect(!titles("TD à rendre pour jeudi 30").isEmpty)
    }

    @Test("Variantes courantes de prise de notes")
    func commonPhrasings() {
        #expect(!titles("DM d'automatique pour le 15 octobre").isEmpty)
        #expect(!titles("exposé à faire pour mardi").isEmpty)
        #expect(!titles("partiel le 12 décembre").isEmpty)
    }

    @Test("Un marqueur qui nomme la chose fait titre ; un autre non")
    func bareMarkerKeepsTitle() {
        // « a rendre » ne nomme rien : la ligne reste sans proposition.
        #expect(titles("à rendre le 15 octobre").isEmpty)
        #expect(titles("partiel le 12 décembre") == ["Partiel"])
        #expect(titles("DM pour le 15 octobre") == ["DM"])
    }

    @Test("Une phrase de cours sans echeance ne propose rien")
    func proseIsIgnored() {
        #expect(titles("le TD montre que la complexite est logarithmique").isEmpty)
    }
}
