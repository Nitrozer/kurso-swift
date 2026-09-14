import Testing
import Foundation
@testable import KursoCore

@Suite("Fiches a collectionner — §11")
struct FicheTests {

    @Test("Une page sans carte reste verrouillee")
    func noCardsStaysLocked() {
        #expect(Fiche.rarity(cardCount: 0, acquired: 0, lapses: 0) == .locked)
        #expect(Fiche.Rarity.locked.dots == 0)
    }

    @Test("Tout su et jamais rate donne une fiche or")
    func flawlessGivesGold() {
        #expect(Fiche.rarity(cardCount: 5, acquired: 5, lapses: 0) == .gold)
        #expect(Fiche.Rarity.gold.dots == 3)
    }

    @Test("Tout su mais des ratés : rare, pas or")
    func lapsesBlockGold() {
        #expect(Fiche.rarity(cardCount: 5, acquired: 5, lapses: 2) == .rare)
    }

    @Test("Largement su donne une rare")
    func mostlyKnownIsRare() {
        #expect(Fiche.rarity(cardCount: 10, acquired: 7, lapses: 0) == .rare)
        #expect(Fiche.rarity(cardCount: 10, acquired: 6, lapses: 0) == .common)
    }

    @Test("A peine commencee, la fiche est commune")
    func barelyStartedIsCommon() {
        #expect(Fiche.rarity(cardCount: 8, acquired: 1, lapses: 0) == .common)
        #expect(Fiche.rarity(cardCount: 8, acquired: 0, lapses: 0) == .common)
    }

    @Test("Le decompte annonce les fiches obtenues et celles en or")
    func summaryCounts() {
        let set: [Fiche.Rarity] = [.gold, .gold, .rare, .common, .locked, .locked]
        #expect(Fiche.summary(set) == "4 SUR 6 · 2 EN OR")
    }

    @Test("Sans fiche en or, on ne le mentionne pas")
    func summaryWithoutGold() {
        #expect(Fiche.summary([.common, .locked]) == "1 SUR 2")
    }
}

@Suite("Carte sue ou non")
struct FicheAcquisitionTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    @Test("Une carte toute neuve n'est pas sue")
    func freshCardIsNotAcquired() {
        #expect(!Fiche.isAcquired(interval: 1, dueAt: now, now: now))
        #expect(!Fiche.isAcquired(interval: 6, dueAt: now.addingTimeInterval(86_400), now: now))
    }

    @Test("Un long intervalle sans retard vaut sue")
    func matureAndOnTimeIsAcquired() {
        #expect(Fiche.isAcquired(interval: 21, dueAt: now.addingTimeInterval(86_400), now: now))
        #expect(Fiche.isAcquired(interval: 60, dueAt: now, now: now))
    }

    @Test("Un long intervalle en retard ne vaut plus sue")
    func matureButLateIsNotAcquired() {
        #expect(!Fiche.isAcquired(interval: 30, dueAt: now.addingTimeInterval(-86_400), now: now))
    }
}
