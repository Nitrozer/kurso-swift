#if os(iOS)
import SwiftUI
import UIKit

/// La feuille de partage du systeme, pour deposer un export dans Fichiers,
/// Mail, ou n'importe quelle app qui accepte un PDF.
struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// Un fichier a partager, identifiable pour `.sheet(item:)`.
struct ExportedFile: Identifiable {
    let url: URL
    var id: String { url.path }
}
#endif
