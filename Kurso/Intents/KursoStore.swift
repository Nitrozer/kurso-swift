import Foundation
import SwiftData
import KursoModels

/// Le conteneur SwiftData, partage par l'application et par les intents.
///
/// Siri execute un intent dans une instance de l'app qui n'a pas forcement
/// d'interface : elle ne peut donc pas emprunter le conteneur de la scene.
enum KursoStore {

    static let schema = Schema([
        Course.self, Page.self, Card.self, Chapter.self, Season.self,
        League.self, LeagueMember.self, Assignment.self, GlossaryTerm.self,
        Abbreviation.self, AudioRecording.self, Quest.self, PlayerState.self,
        Timetable.self, TimeSlot.self, MarkerFeedback.self, PDFAsset.self, DailyActivity.self,
        PageImage.self, PageText.self, ExamSnapshot.self, ExamPaper.self,
        Friend.self, ClassGroup.self, FriendRequest.self, NoteAsk.self, DismissedSlot.self,
    ])

    /// `cloudKitDatabase` reste desactive tant que le compte developpeur n'est
    /// pas actif : le schema est deja conforme (defauts partout, relations
    /// optionnelles avec inverse), donc le passage a `.private` se fera sans
    /// migration.
    static let container: ModelContainer = {
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("ModelContainer: \(error)")
        }
    }()
}
