import Testing
import Foundation
@testable import KursoModels

/// Pourquoi une zone masquee n'est pas un CGRect.
///
/// SwiftData encode les attributs composites avec un conteneur A CLES. Un
/// CGRect, lui, s'encode en tableau `[x, y, w, h]` : l'enregistrement d'une
/// carte a occlusion plantait sur
/// « Composite Coder only supports Keyed Container ».
///
/// Ces deux tests verrouillent la raison, sans monter de base : un conteneur
/// SwiftData en memoire fait tomber le processus de test quand plusieurs
/// suites tournent en parallele.
@Suite("Zone masquee — encodage")
struct OcclusionStorageTests {

    @Test("La zone masquee s'encode avec des clés, ce que SwiftData exige")
    func boxIsKeyed() throws {
        let data = try JSONEncoder().encode(OcclusionBox(x: 0.1, y: 0.2, width: 0.3, height: 0.4))
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["x"] as? Double == 0.1)
        #expect(json["width"] as? Double == 0.3)
        #expect(json["height"] as? Double == 0.4)
    }

    @Test("Un CGRect s'encode en tableau, ce que SwiftData refuse")
    func cgRectIsUnkeyed() throws {
        let data = try JSONEncoder().encode(CGRect(x: 1, y: 2, width: 3, height: 4))
        let decoded = try JSONSerialization.jsonObject(with: data)
        #expect(decoded is [Any], "si CGRect devenait clé, le contournement ne servirait plus")
    }

    @Test("L'aller-retour par CGRect conserve la zone")
    func roundTrip() {
        let card = Card(question: "Que cache cette zone ?", kind: .imageOcclusion, dueAt: .now)
        card.occlusionRect = CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4)
        let rect = card.occlusionRect
        #expect(rect?.minX == 0.1)
        #expect(rect?.height == 0.4)
        #expect(card.occlusion?.width == 0.3)
    }

    @Test("Sans zone, la carte n'en invente pas")
    func noBoxStaysNil() {
        let card = Card(question: "Recto verso", kind: .frontBack, dueAt: .now)
        #expect(card.occlusionRect == nil)
        #expect(card.occlusion == nil)
    }
}

@Suite("Types refuses par SwiftData")
struct UnstorableTypeTests {
    @Test("Un Range s'encode en tableau, comme un CGRect")
    func rangeIsUnkeyed() throws {
        let data = try JSONEncoder().encode(3..<7)
        let decoded = try JSONSerialization.jsonObject(with: data)
        #expect(decoded is [Any], "si Range devenait clé, le contournement ne servirait plus")
    }
}
