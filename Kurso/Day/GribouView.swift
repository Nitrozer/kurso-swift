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
    /// Part de la hauteur du cadre que le personnage occupe. En dessous de 1,
    /// il flotte dans du vide ; au-dessus, la gomme touche le bord.
    var fill: Float = 1.0

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

        dropOutlineShell(entity)

        // Cadrer sur la HAUTEUR, une fois la coque retiree. Se caler sur la
        // plus grande dimension revenait au meme tant que le personnage etait
        // debout, mais laissait la moitie du carre vide des qu'il s'inclinait :
        // un crayon est trois fois plus haut que large.
        let bounds = entity.visualBounds(relativeTo: nil)
        let height = max(bounds.extents.y, 0.0001)
        let scale = 2.0 * fill / height
        entity.scale = .init(repeating: scale)
        let center = bounds.center * scale
        entity.position = .init(x: -center.x, y: -center.y, z: -center.z)

        // UNE SEULE animation. RealityKit expose la meme deux fois — « global
        // scene animation » et « default subtree animation » — et les jouer
        // toutes les deux superposait le clip sur lui-meme.
        if let clip = entity.availableAnimations.first {
            entity.playAnimation(clip.repeat(), transitionDuration: 0.3, startsPaused: false)
        }

        let anchor = Entity()
        anchor.addChild(entity)
        content.add(anchor)
    }

    /// Retire la coque de contour.
    ///
    /// C'est une coque retournee, plus grande que le personnage, qui donne le
    /// trait noir dans Blender. RealityKit ne sait pas la rendre : elle est
    /// soit eliminee, soit dessinee DEVANT — et Gribou vire alors au noir
    /// complet. Autant ne pas la charger : elle pese 4 180 triangles sur les
    /// 11 926 du modele, plus d'un tiers, pour un effet qu'on ne voyait pas.
    @MainActor
    private func dropOutlineShell(_ entity: Entity) {
        for child in entity.children where child.name.localizedCaseInsensitiveContains("contour") {
            child.isEnabled = false
            child.removeFromParent()
        }
        for child in entity.children { dropOutlineShell(child) }
    }
}
