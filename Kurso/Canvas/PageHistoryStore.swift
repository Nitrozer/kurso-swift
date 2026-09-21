#if os(iOS)
import Foundation
import SwiftData
import PencilKit
import KursoCore
import KursoModels

/// Garde et rend les etats anterieurs d'une page.
enum PageHistoryStore {

    /// Retient l'etat actuel, si l'instant s'y prete.
    ///
    /// Appele a chaque enregistrement, donc tres souvent : tout le travail
    /// consiste a repondre non sans rien lire. La comparaison porte sur le
    /// NOMBRE de traits, jamais sur les octets du trace — ceux-ci vivent hors
    /// de la base, et les relire a chaque geste toucherait le disque pendant
    /// qu'on ecrit.
    @MainActor
    static func keepIfNeeded(_ page: Page, strokes: Int, drawing: Data?,
                             now: Date = .now, context: ModelContext) {
        let kept = (page.snapshots ?? []).sorted { $0.takenAt < $1.takenAt }
        let last = kept.last
        let changed = last.map { $0.strokeCount != strokes } ?? (strokes > 0)
        guard PageHistory.shouldKeep(last: last?.takenAt, now: now, changed: changed) else { return }

        let made = PageSnapshot(drawing: drawing, strokeCount: strokes, takenAt: now)
        made.page = page
        context.insert(made)
        prune(page, now: now, context: context)
        try? context.save()
    }

    /// Retire ce qui a trop vieilli, puis ce qui depasse le compte.
    @MainActor
    static func prune(_ page: Page, now: Date = .now, context: ModelContext) {
        var kept = (page.snapshots ?? []).sorted { $0.takenAt < $1.takenAt }
        let tooOld = Set(PageHistory.expired(kept.map(\.takenAt), now: now))
        for snapshot in kept where tooOld.contains(snapshot.takenAt) {
            context.delete(snapshot)
        }
        kept.removeAll { tooOld.contains($0.takenAt) }

        while let doomed = PageHistory.expendable(kept.map(\.takenAt)),
              let victim = kept.first(where: { $0.takenAt == doomed }) {
            context.delete(victim)
            kept.removeAll { $0.takenAt == doomed }
        }
    }

    /// Rend la page a cet etat.
    ///
    /// L'etat ACTUEL est retenu d'abord : revenir en arriere doit pouvoir se
    /// defaire, sinon on remplace une perte par une autre.
    @MainActor
    static func restore(_ snapshot: PageSnapshot, into page: Page,
                        context: ModelContext) -> PKDrawing {
        let current = page.drawing
        let currentStrokes = (current.flatMap { try? PKDrawing(data: $0) })?.strokes.count ?? 0
        // Pas deux fois le meme etat : si le dernier instantane porte deja ce
        // trace, le retenir a nouveau n'ajouterait qu'une ligne identique dans
        // une liste ou l'on cherche justement a se reperer.
        let newest = (page.snapshots ?? []).max { $0.takenAt < $1.takenAt }
        if current != snapshot.drawing, newest?.drawing != current {
            let safety = PageSnapshot(drawing: current, strokeCount: currentStrokes, takenAt: .now)
            safety.page = page
            context.insert(safety)
        }

        page.drawing = snapshot.drawing
        prune(page, context: context)
        try? context.save()
        return (snapshot.drawing.flatMap { try? PKDrawing(data: $0) }) ?? PKDrawing()
    }
}
#endif
