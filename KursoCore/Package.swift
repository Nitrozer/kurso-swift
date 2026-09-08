// swift-tools-version: 6.0
import PackageDescription

// Deux cibles, pour la raison donnee au §11bis de PASSATION.md :
//   KursoCore   — logique metier pure. Aucun import UI, aucun import SwiftData.
//                 Testable sans lancer l'app, et seule partie traduisible ailleurs.
//   KursoModels — les @Model SwiftData. Depend de SwiftData, jamais de SwiftUI.
// La cible applicative (Xcode) importera les deux et n'y ajoutera que des vues.
let package = Package(
    name: "KursoCore",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "KursoCore", targets: ["KursoCore"]),
        .library(name: "KursoModels", targets: ["KursoModels"]),
    ],
    targets: [
        .target(name: "KursoCore"),
        .target(name: "KursoModels"),
        .testTarget(name: "KursoCoreTests", dependencies: ["KursoCore", "KursoModels"]),
    ]
)
