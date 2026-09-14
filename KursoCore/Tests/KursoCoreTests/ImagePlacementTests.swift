import Testing
import Foundation
import CoreGraphics
@testable import KursoCore

@Suite("Placement d'une image dans la page")
struct ImagePlacementTests {
    private let page = CGRect(x: 0, y: 0, width: 1_000, height: 2_000)

    @Test("Sans reglage, l'image occupe la largeur et se cale en haut")
    func defaultFitsWidth() {
        let r = ImagePlacement.placement(image: CGSize(width: 200, height: 100), box: nil, in: page)
        #expect(r.width == 1_000)
        #expect(r.height == 500)
        #expect(r.minY == 0)
    }

    @Test("Une image trop haute est ajustee sur la hauteur, et centree")
    func tallImageFitsHeight() {
        let r = ImagePlacement.placement(image: CGSize(width: 100, height: 400), box: nil, in: page)
        #expect(r.height == 2_000)
        #expect(r.width == 500)
        #expect(r.midX == page.midX)
    }

    @Test("Un reglage est suivi a la lettre")
    func boxIsHonoured() {
        let box = CGRect(x: 0.25, y: 0.1, width: 0.5, height: 0.2)
        let r = ImagePlacement.placement(image: CGSize(width: 10, height: 10), box: box, in: page)
        #expect(r.minX == 250)
        #expect(r.minY == 200)
        #expect(r.width == 500)
        #expect(r.height == 400)
    }

    @Test("Un reglage vide est ignore")
    func emptyBoxFallsBack() {
        let r = ImagePlacement.placement(image: CGSize(width: 200, height: 100),
                                         box: CGRect(x: 0.2, y: 0.2, width: 0, height: 0), in: page)
        #expect(r.width == 1_000)
    }

    @Test("L'aller-retour ecran ↔ fractions ne perd rien")
    func roundTrip() throws {
        let box = CGRect(x: 0.2, y: 0.35, width: 0.4, height: 0.15)
        let onScreen = ImagePlacement.placement(image: .zero, box: box, in: page)
        let back = try #require(ImagePlacement.box(from: onScreen, in: page))
        #expect(abs(back.minX - box.minX) < 0.0001)
        #expect(abs(back.minY - box.minY) < 0.0001)
        #expect(abs(back.width - box.width) < 0.0001)
        #expect(abs(back.height - box.height) < 0.0001)
    }

    @Test("Le placement suit le zoom de la page")
    func followsZoom() {
        let zoomed = CGRect(x: -300, y: -500, width: 2_000, height: 4_000)
        let box = CGRect(x: 0.5, y: 0, width: 0.5, height: 0.25)
        let r = ImagePlacement.placement(image: .zero, box: box, in: zoomed)
        #expect(r.minX == 700)
        #expect(r.width == 1_000)
    }
}
