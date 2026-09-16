import SwiftUI

extension View {
    /// Impose une taille aux feuilles sur macOS.
    ///
    /// Les ecrans de Kurso occupent la place qu'on leur donne : ils sont batis
    /// en `maxWidth: .infinity` et n'ont donc aucune taille naturelle. Sur iOS
    /// cela n'a pas d'importance — une feuille y est plein ecran ou detachee.
    /// Sur macOS, une feuille se dimensionne a son contenu : sans plancher,
    /// elles s'ecrasaient jusqu'a ne plus montrer qu'une bande de quelques
    /// dizaines de points.
    ///
    /// `min` et `ideal` a la fois : le premier empeche l'ecrasement, le second
    /// donne la taille d'ouverture.
    func macSheet(_ width: CGFloat, _ height: CGFloat) -> some View {
        #if os(macOS)
        frame(minWidth: width, idealWidth: width, minHeight: height, idealHeight: height)
        #else
        self
        #endif
    }
}
