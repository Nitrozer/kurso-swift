import SwiftUI
import RealityKit
import KursoCore

/// Gribou en trois dimensions.
///
/// Il n'est pas un logo posé : sa mine s'use avec les heures écrites et se
/// retaille au passage de niveau. C'est la progression rendue visible sur le
/// personnage plutôt que dans une barre.
struct GribouView: View {
    let mood: GribouMood
    var size: CGFloat = 150

    var body: some View {
        RealityView { content in
            await load(mood, into: content)
        }
        // Changer d'humeur reconstruit la vue plutôt que de recharger dedans :
        // la fermeture de mise à jour reçoit son contenu en `inout` et ne peut
        // donc pas le confier à une tâche asynchrone.
        .id(mood)
        .frame(width: size, height: size)
        .accessibilityLabel("Gribou, \(mood.label)")
    }

    @MainActor
    private func load(_ mood: GribouMood, into content: RealityViewCameraContent) async {
        content.entities.removeAll()
        guard let entity = try? await Entity(named: mood.clipName, in: .main) else { return }

        // Cadrage calcule depuis les bornes reelles du modele : une valeur
        // devinee coupait la tete, et chaque clip a une amplitude differente.
        let bounds = entity.visualBounds(relativeTo: nil)
        let extent = max(bounds.extents.x, bounds.extents.y, bounds.extents.z)
        if extent > 0 {
            entity.scale = .init(repeating: 1.6 / extent)
        }
        let center = bounds.center * (extent > 0 ? 1.6 / extent : 1)
        entity.position = .init(x: -center.x, y: -center.y, z: -center.z)

        // Les clips sont des boucles : la respiration de 2,6 s au repos, les
        // autres à leur propre rythme. Rien ne se synchronise, c'est voulu.
        for animation in entity.availableAnimations {
            entity.playAnimation(animation.repeat(), transitionDuration: 0.3, startsPaused: false)
        }

        let anchor = Entity()
        anchor.addChild(entity)
        content.add(anchor)
    }
}
