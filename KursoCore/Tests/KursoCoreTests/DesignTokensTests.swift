import Testing
@testable import KursoCore

@Suite("Jetons de design — §13 et §3 de PASSATION.md")
struct DesignTokensTests {

    @Test("L'encre du manuscrit ne descend jamais sous 0.35")
    func inkNeverBelowFloor() {
        // §3 : « Jamais en dessous de 0.35 — le texte doit rester lisible. »
        for step in 0...100 {
            let freshness = Double(step) / 100
            #expect(DesignTokens.Freshness.inkOpacity(forFreshness: freshness) >= 0.35)
        }
        // Y compris hors bornes, si un calcul amont derape.
        #expect(DesignTokens.Freshness.inkOpacity(forFreshness: -5) >= 0.35)
        #expect(DesignTokens.Freshness.inkOpacity(forFreshness: 12) <= 1.0)
    }

    @Test("Les extremes correspondent aux valeurs du document")
    func inkBounds() {
        #expect(DesignTokens.Freshness.inkOpacity(forFreshness: 0) == 0.35)
        #expect(DesignTokens.Freshness.inkOpacity(forFreshness: 1) == 1.0)
    }

    @Test("Les seuils de fraicheur sont ceux du tableau du §3")
    func thresholds() {
        #expect(DesignTokens.Freshness.acquired == 0.75)
        #expect(DesignTokens.Freshness.toReview == 0.40)
    }
}
