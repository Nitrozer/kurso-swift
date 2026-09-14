import Testing
@testable import KursoCore

@Suite("Couleur d'un cahier")
struct CourseColorTests {

    @Test("Les matieres importees ne sortent pas toutes de la meme couleur")
    func importedCoursesDiffer() {
        let first = (0..<5).map { CourseColor.forIndex($0) }
        #expect(Set(first).count == 5)
    }

    @Test("Au-dela de cinq, les couleurs recommencent")
    func wrapsAround() {
        #expect(CourseColor.forIndex(5) == CourseColor.forIndex(0))
        #expect(CourseColor.forIndex(7) == CourseColor.forIndex(2))
    }

    @Test("Un index negatif ne fait pas planter")
    func negativeIndex() {
        #expect(CourseColor.allCases.contains(CourseColor.forIndex(-3)))
    }

    @Test("Un jeton inconnu retombe sur le bleu")
    func unknownTokenFallsBack() {
        #expect(CourseColor.named("turquoise") == .blue)
        #expect(CourseColor.named("pink") == .pink)
    }
}
