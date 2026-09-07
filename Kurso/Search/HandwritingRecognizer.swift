import Foundation
import Vision
import PencilKit

/// Reconnaissance du manuscrit, pour la recherche.
///
/// Le texte reconnu ne remplace jamais le trace et ne s'affiche jamais a la
/// place des notes : il ne sert qu'a retrouver une page, et a proposer un titre
/// (§4). Rien n'est envoye nulle part — Vision travaille sur l'appareil.
enum HandwritingRecognizer {

    /// Rend le texte reconnu, ligne par ligne, ou une chaine vide.
    static func recognize(_ drawing: PKDrawing) async -> String {
        guard !drawing.bounds.isEmpty else { return "" }

        // Un rendu a 2x donne assez de matiere a Vision sans exploser la memoire
        // sur une page de deux heures de cours.
        let rendered = drawing.image(from: drawing.bounds, scale: 2)
        guard let cgImage = rendered.asCGImage else { return "" }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["fr-FR", "en-US"]
        // Les notes de cours sont pleines d'abreviations et de symboles que le
        // correcteur de langue transformerait — or on ne reecrit jamais (§4).
        request.usesLanguageCorrection = false

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return ""
        }

        let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        return lines.joined(separator: "\n")
    }
}

#if canImport(UIKit)
import UIKit
private extension UIImage {
    var asCGImage: CGImage? { cgImage }
}
#else
import AppKit
private extension NSImage {
    var asCGImage: CGImage? { cgImage(forProposedRect: nil, context: nil, hints: nil) }
}
#endif
