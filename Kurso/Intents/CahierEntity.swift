import AppIntents
import SwiftData
import KursoModels

/// Un cahier, tel que Siri le voit.
///
/// **Le nom de la matiere et rien d'autre.** Pas une page, pas une carte, pas
/// une ligne de cours : le §12 interdit que les donnees de cours quittent
/// l'appareil, et une entite exposee est lisible par l'assistant. De quoi
/// naviguer, donc, jamais de quoi lire.
struct CahierEntity: AppEntity {
    let id: UUID
    let name: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Cahier" }
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
    static let defaultQuery = CahierQuery()
}

struct CahierQuery: EntityQuery {

    @MainActor
    private func courses() -> [Course] {
        let context = ModelContext(KursoStore.container)
        return (try? context.fetch(FetchDescriptor<Course>())) ?? []
    }

    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [CahierEntity] {
        let wanted = Set(identifiers)
        return courses()
            .filter { wanted.contains($0.id) }
            .map { CahierEntity(id: $0.id, name: $0.name) }
    }

    @MainActor
    func suggestedEntities() async throws -> [CahierEntity] {
        courses().map { CahierEntity(id: $0.id, name: $0.name) }
    }
}

extension CahierQuery: EntityStringQuery {
    @MainActor
    func entities(matching string: String) async throws -> [CahierEntity] {
        courses()
            .filter { $0.name.localizedCaseInsensitiveContains(string) }
            .map { CahierEntity(id: $0.id, name: $0.name) }
    }
}
