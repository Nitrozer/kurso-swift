#if os(iOS)
import SwiftUI
import UIKit

/// L'appareil photo de l'iPad, pour poser une photo sur la page.
///
/// `UIImagePickerController` plutot qu'AVFoundation : on veut l'appareil photo
/// du systeme, avec sa mise au point et son declencheur, pas une camera a
/// reconstruire. Une photo de tableau n'a pas besoin de mieux.
///
/// Pas de recadrage : `allowsEditing` impose un cadre carre, et un tableau
/// n'est jamais carre. On recadre en deplacant l'image sur la page, comme
/// toutes les autres.
struct CameraPicker: UIViewControllerRepresentable {
    var onCapture: (UIImage) -> Void
    var onCancel: () -> Void

    /// Faux au simulateur, et sur un appareil dont l'acces est refuse par un
    /// reglage d'ecran. On n'affiche pas une entree de menu qui ne ferait rien.
    static var isAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let parent: CameraPicker

        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            guard let image = info[.originalImage] as? UIImage else {
                parent.onCancel()
                return
            }
            parent.onCapture(image)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onCancel()
        }
    }
}
#endif
