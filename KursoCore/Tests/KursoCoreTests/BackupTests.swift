import Foundation
import Testing
@testable import KursoCore

@Suite("Sauvegarde")
struct BackupTests {

    private func sample() -> Backup.Archive {
        let courseID = UUID(), pageID = UUID()
        return Backup.Archive(
            createdAt: Date(timeIntervalSince1970: 1_800_000_000),
            courses: [.init(id: courseID, name: "Automatique", colorToken: "blue",
                            coverStyle: "kraft", icsUID: nil, teacher: "GIMMIG",
                            archivedAt: nil, seasonID: nil)],
            pages: [.init(id: pageID, title: "Tas binaires", titleWasEdited: true, position: 1_000,
                          templateRaw: "ruled", createdAt: Date(timeIntervalSince1970: 1_799_000_000),
                          writingSeconds: 900, markdown: "", recognizedText: "Tas binaire : arbre",
                          sessionEnd: nil, sprintProposedAt: nil, masteredAt: nil,
                          drawing: Data([0x01, 0x02, 0x03]), photo: nil,
                          photoX: nil, photoY: nil, photoW: nil, photoH: nil,
                          pdfAssetID: nil, pdfPageIndex: nil, courseID: courseID)],
            cards: [.init(id: UUID(), kindRaw: "frontBack", question: "Tas binaire ?",
                          answerText: "arbre presque complet", answerDrawing: nil, imageData: nil,
                          occX: 0.1, occY: 0.2, occW: 0.3, occH: 0.4,
                          sourceLineStart: 3, sourceLineEnd: 4,
                          interval: 21, ease: 2.5, dueAt: Date(timeIntervalSince1970: 1_801_000_000),
                          lapses: 1, isInMistakeBook: false, pageID: pageID)]
        )
    }

    @Test("Un aller-retour ne perd rien")
    func roundTrip() throws {
        let archive = sample()
        let decoded = try Backup.decode(try Backup.encode(archive))
        #expect(decoded == archive)
    }

    @Test("Les traits survivent au voyage")
    func drawingSurvives() throws {
        let decoded = try Backup.decode(try Backup.encode(sample()))
        #expect(decoded.pages.first?.drawing == Data([0x01, 0x02, 0x03]))
    }

    @Test("Un fichier illisible est refuse, pas devine")
    func garbage() {
        #expect(throws: Backup.Failure.unreadable) {
            try Backup.decode(Data("pas du json".utf8))
        }
    }

    @Test("Une sauvegarde venue du futur est refusee")
    func fromTheFuture() throws {
        // Restaurer un format qu'on ne comprend pas ferait pire que rien.
        var archive = sample()
        archive.version = Backup.currentVersion + 1
        let data = try Backup.encode(archive)
        #expect(throws: Backup.Failure.tooRecent(version: Backup.currentVersion + 1)) {
            try Backup.decode(data)
        }
    }

    @Test("Le resume annonce ce que contient le fichier")
    func summary() {
        #expect(sample().summary == "1 page · 1 cahier · 1 carte")
    }

    @Test("Le nom de fichier porte la date")
    func fileName() {
        let name = Backup.fileName(for: Date(timeIntervalSince1970: 1_800_000_000))
        #expect(name.hasSuffix(".kursobackup"))
        #expect(name.contains("2027-01-15") || name.contains("2027-01-16"))
    }
}
