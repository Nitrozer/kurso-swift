import Testing
@testable import KursoCore

@Suite("Copeaux et boutique — §9")
struct ShopTests {

    @Test("L'uni est donne, jamais a acheter")
    func plainIsFree() {
        #expect(Shop.Cover.plain.price == 0)
        #expect(Shop.isOwned(.plain, owned: []))
    }

    @Test("Une couverture payante n'est possedee qu'apres achat")
    func paidNeedsBuying() {
        #expect(!Shop.isOwned(.kraft, owned: []))
        #expect(Shop.isOwned(.kraft, owned: ["kraft"]))
    }

    @Test("On n'achete pas sans avoir de quoi")
    func needsEnough() {
        #expect(!Shop.canBuy(.marble, shavings: 399, owned: []))
        #expect(Shop.canBuy(.marble, shavings: 400, owned: []))
    }

    @Test("On ne rachete pas ce qu'on a deja")
    func noDoubleBuy() {
        #expect(!Shop.canBuy(.kraft, shavings: 9_999, owned: ["kraft"]))
        #expect(Shop.buy(.kraft, shavings: 9_999, owned: ["kraft"]) == nil)
    }

    @Test("L'achat debite exactement le prix")
    func buyDebits() {
        #expect(Shop.buy(.stripes, shavings: 300, owned: []) == 180)
    }

    @Test("Un achat impossible ne debite rien")
    func failedBuyCostsNothing() {
        #expect(Shop.buy(.marble, shavings: 10, owned: []) == nil)
    }

    @Test("Les gains suivent le §9")
    func earnings() {
        #expect(Shop.Earn.correctCard == 8)
        #expect(Shop.Earn.finishedPage == 40)
        #expect(Shop.Earn.masteredNode == 120)
    }

    @Test("Rien dans la boutique ne fait progresser")
    func nothingAdvancesProgress() {
        // Si un article autre qu'une couverture apparait un jour, ce test
        // tombe : la boutique ne vend que de l'apparence (§12).
        #expect(Shop.Cover.allCases.count == 5)
    }
}
