import Testing
@testable import KursoCore

@Suite("Ce que Siri annonce")
struct ReviewAnnouncementTests {

    @Test("Rien a reviser")
    func nothing() {
        #expect(ReviewAnnouncement.sentence(due: 0) == "Rien à réviser pour l'instant.")
    }

    @Test("Une carte se dit au singulier")
    func one() {
        #expect(ReviewAnnouncement.sentence(due: 1) == "Une carte t'attend.")
    }

    @Test("Plusieurs cartes")
    func many() {
        #expect(ReviewAnnouncement.sentence(due: 12) == "12 cartes t'attendent.")
    }

    @Test("Un compte negatif ne dit pas de betise")
    func negative() {
        // Ne devrait pas arriver, mais une phrase parlee ne doit jamais
        // annoncer « -3 cartes t'attendent ».
        #expect(ReviewAnnouncement.sentence(due: -3) == "Rien à réviser pour l'instant.")
    }

    @Test("L'ouverture nomme le cahier")
    func opening() {
        #expect(ReviewAnnouncement.opening("Automatique") == "J'ouvre Automatique.")
        #expect(ReviewAnnouncement.opening("") == "J'ouvre ton cahier.")
    }
}
