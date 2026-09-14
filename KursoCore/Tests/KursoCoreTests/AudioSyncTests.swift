import Testing
import Foundation
import CoreGraphics
@testable import KursoCore

@Suite("Audio colle a l'ecriture — §7")
struct AudioSyncTests {
    private func mark(_ x: CGFloat, _ y: CGFloat, at offset: Double) -> AudioSync.Mark {
        AudioSync.Mark(strokeID: UUID(), offsetSeconds: offset, anchor: CGPoint(x: x, y: y))
    }

    @Test("On remonte deux secondes avant le trait")
    func leadsByTwoSeconds() {
        #expect(AudioSync.playbackTime(for: mark(0, 0, at: 12)) == 10)
    }

    @Test("On ne remonte jamais avant le debut")
    func neverBeforeZero() {
        #expect(AudioSync.playbackTime(for: mark(0, 0, at: 1)) == 0)
        #expect(AudioSync.playbackTime(for: mark(0, 0, at: 0)) == 0)
    }

    @Test("Le trait le plus proche gagne")
    func nearestWins() throws {
        let marks = [mark(0, 0, at: 5), mark(100, 0, at: 30), mark(40, 0, at: 18)]
        let found = try #require(AudioSync.nearest(to: CGPoint(x: 45, y: 0), among: marks, within: 80))
        #expect(found.offsetSeconds == 18)
    }

    @Test("Toucher le vide ne joue rien")
    func emptyAreaPlaysNothing() {
        let marks = [mark(0, 0, at: 5)]
        #expect(AudioSync.nearest(to: CGPoint(x: 900, y: 900), among: marks, within: 80) == nil)
        #expect(AudioSync.nearest(to: .zero, among: [], within: 80) == nil)
    }

    @Test("Le rayon est respecte a la limite")
    func radiusBoundary() {
        let marks = [mark(0, 30, at: 7)]
        #expect(AudioSync.nearest(to: .zero, among: marks, within: 30) != nil)
        #expect(AudioSync.nearest(to: .zero, among: marks, within: 29) == nil)
    }

    @Test("La duree s'ecrit en minutes et secondes")
    func clockFormat() {
        #expect(AudioSync.clock(0) == "0:00")
        #expect(AudioSync.clock(72) == "1:12")
        #expect(AudioSync.clock(3_605) == "60:05")
        #expect(AudioSync.clock(-4) == "0:00")
    }
}
