import Testing
import Foundation
@testable import KursoModels
import KursoCore

/// Un PDF de trois diapos ne doit pas remplir les cahiers de trois notes :
/// c'est ce qui donnait l'impression que l'app en creait toute seule.
@Suite("Diapos regroupees")
struct SlideGroupingTests {

    private func slide(_ asset: UUID, _ index: Int) -> Page {
        let page = Page(title: "VOC 13 — \(index + 1)", createdAt: .now)
        page.pdfAssetID = asset
        page.pdfPageIndex = index
        return page
    }

    @Test("Les diapos d'un meme PDF ne font qu'une entree")
    func onePDFOneEntry() {
        let asset = UUID()
        let pages = (0..<3).map { slide(asset, $0) }
        let shown = Page.collapsingSlides(pages)
        #expect(shown.count == 1)
        #expect(shown.first?.pdfPageIndex == 0)
    }

    @Test("Deux PDF distincts font deux entrees")
    func twoPDFsTwoEntries() {
        let pages = [slide(UUID(), 0), slide(UUID(), 0)]
        #expect(Page.collapsingSlides(pages).count == 2)
    }

    @Test("Les pages ecrites a la main ne sont jamais regroupees")
    func handwrittenPagesUntouched() {
        let a = Page(createdAt: .now), b = Page(createdAt: .now)
        #expect(Page.collapsingSlides([a, b]).count == 2)
    }

    @Test("Un melange garde les pages ecrites et une seule entree par PDF")
    func mixed() {
        let asset = UUID()
        let pages = [Page(createdAt: .now), slide(asset, 0), slide(asset, 1), Page(createdAt: .now)]
        #expect(Page.collapsingSlides(pages).count == 3)
    }
}

@Suite("Titre d'une entree de PDF")
struct SlideTitleTests {
    @Test("Le numero de diapo disparait")
    func stripsNumber() {
        #expect(PageTitle.withoutSlideNumber("VOC 13 — 3") == "VOC 13")
        #expect(PageTitle.withoutSlideNumber("Cours de maths — 12") == "Cours de maths")
    }

    @Test("Un titre ecrit par l'etudiant n'est jamais ampute")
    func keepsRealTitles() {
        #expect(PageTitle.withoutSlideNumber("Chapitre 2 — les tas") == "Chapitre 2 — les tas")
        #expect(PageTitle.withoutSlideNumber("VOC 13") == "VOC 13")
        #expect(PageTitle.withoutSlideNumber("") == "")
    }
}
