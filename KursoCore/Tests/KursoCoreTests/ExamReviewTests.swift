import Foundation
import Testing
@testable import KursoCore

@Suite("Retour sur copie")
struct ExamReviewTests {

    private func miss(_ points: Double, _ state: Freshness.State?,
                      kind: ExamReview.Miss.Kind = .exercise) -> ExamReview.Miss {
        .init(label: "Exercice", points: points, kind: kind, stateAtExam: state)
    }

    @Test("Les points perdus viennent du bareme")
    func lostPoints() {
        let verdict = ExamReview.verdict(misses: [], grade: 14, outOf: 20)
        #expect(verdict.lostPoints == 6)
        #expect(verdict.lostPointsLabel == "6")
    }

    @Test("Une note parfaite ne perd rien")
    func perfect() {
        let verdict = ExamReview.verdict(misses: [], grade: 20, outOf: 20)
        #expect(verdict.lostPoints == 0)
        #expect(ExamReview.headline(verdict) == "Tu n'as rien laissé en route.")
    }

    @Test("Une note au-dessus du bareme ne rend pas de points negatifs")
    func aboveScale() {
        // Un bonus peut faire 21/20 : le titre ne doit pas dire « -1 point ».
        #expect(ExamReview.verdict(misses: [], grade: 21, outOf: 20).lostPoints == 0)
    }

    @Test("Un rate sur page fragile fait remonter la page")
    func fragileLiftsPage() {
        let verdict = ExamReview.verdict(misses: [miss(3, .endangered)], grade: 17, outOf: 20)
        #expect(verdict.onFragilePages == 1)
        #expect(verdict.adjustments.contains(.sickPagesFirst(pages: 1)))
        // Un seul rate ne suffit pas a avancer le mode partiel.
        #expect(!verdict.adjustments.contains(.earlierExamMode))
    }

    @Test("Deux rates fragiles avancent le mode partiel")
    func twoFragileMovesExamMode() {
        let verdict = ExamReview.verdict(
            misses: [miss(3, .endangered), miss(2, .toReview)], grade: 15, outOf: 20)
        #expect(verdict.adjustments.contains(.earlierExamMode))
    }

    @Test("Un rate sur page acquise ne reproche rien a la page")
    func acquiredIsNotBlamed() {
        // La page etait verte : ce n'est pas la memoire qui a lache.
        let verdict = ExamReview.verdict(misses: [miss(1, .acquired)], grade: 19, outOf: 20)
        #expect(verdict.onFragilePages == 0)
        #expect(verdict.adjustments.isEmpty)
        #expect(ExamReview.conclusion(verdict) == nil)
    }

    @Test("Une page sans photographie ne compte pas comme fragile")
    func withoutSnapshot() {
        // Partiel passe avant que Kurso ne photographie : on ne devine pas.
        let verdict = ExamReview.verdict(misses: [miss(2, nil)], grade: 18, outOf: 20)
        #expect(verdict.onFragilePages == 0)
    }

    @Test("Une question de cours ouvre les cartes de definition")
    func courseQuestion() {
        let verdict = ExamReview.verdict(
            misses: [miss(1, .acquired, kind: .courseQuestion)], grade: 19, outOf: 20)
        #expect(verdict.adjustments.contains(.definitionCards))
    }

    @Test("Le titre s'accorde au singulier")
    func singular() {
        let verdict = ExamReview.verdict(misses: [], grade: 19, outOf: 20)
        #expect(ExamReview.headline(verdict) == "Où est parti le 1 point qui manquait")
    }

    @Test("Le mode partiel avance aux valeurs du §9")
    func windowValues() {
        let detail = ExamReview.Adjustment.earlierExamMode.detail
        #expect(detail.contains("J-21"))
        #expect(detail.contains("J-14"))
    }
}
