import SwiftUI
import PencilKit
import SwiftData
import KursoCore
import KursoModels

/// Vignette d'une page.
///
/// L'apercu montre le vrai trace, jamais une police cursive : Caveat sert a
/// representer le manuscrit DANS LES MAQUETTES, l'app affiche l'encre reelle.
struct PageCard: View {
    let page: Page
    /// Nombre de diapos quand la vignette represente un PDF entier.
    var slideCount: Int?
    var isActive = false
    var action: () -> Void
    var onDelete: (() -> Void)? = nil

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                preview
                footer
            }
            .background(K.paperAlt, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isActive ? K.brand : K.ink, lineWidth: 3)
            )
            .background(alignment: .top) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isActive ? K.brand : K.ink)
                    .offset(y: 4)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let onDelete {
                Button("Supprimer la page", role: .destructive, action: onDelete)
            }
        }
    }

    private var preview: some View {
        ZStack {
            DottedPaper()
            if let image = thumbnail {
                image.resizable().scaledToFit().padding(6)
            }
        }
        .frame(height: 96)
        .clipped()
    }

    /// Une vignette qui represente tout un PDF porte son nom, sans numero.
    private var displayTitle: String {
        guard !page.title.isEmpty else { return "Sans titre" }
        return slideCount == nil ? page.title : PageTitle.withoutSlideNumber(page.title)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(page.createdAt, format: .dateTime.day().month(.twoDigits))
                    .font(KFont.mono(9))
                    .foregroundStyle(K.inkSoft)
                if let slideCount {
                    Text("\(slideCount) diapos")
                        .font(KFont.mono(9))
                        .foregroundStyle(K.ink)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(K.reward, in: Capsule())
                        .overlay(Capsule().strokeBorder(K.ink, lineWidth: 1.5))
                }
                Spacer()
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(freshnessColor)
                    .frame(width: 9, height: 9)
            }
            Text(displayTitle)
                .font(KFont.body(12, weight: .extraBold))
                .foregroundStyle(K.ink)
                .lineLimit(2)
                .frame(height: 29, alignment: .top)
            Text(freshnessLabel)
                .font(KFont.body(10, weight: .bold))
                .foregroundStyle(freshnessTextColor)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .overlay(alignment: .top) {
            Rectangle().fill(isActive ? K.brand : K.ink).frame(height: 3)
        }
    }

    private var thumbnail: Image? {
        guard let data = page.drawing, let drawing = try? PKDrawing(data: data),
              !drawing.bounds.isEmpty else { return nil }
        let rendered = drawing.image(from: drawing.bounds, scale: 1)
        #if canImport(UIKit)
        return Image(uiImage: rendered)
        #else
        return Image(nsImage: rendered)
        #endif
    }

    /// L'etat reel de la page, calcule depuis ses cartes (§3). Il etait ecrit
    /// en dur : la page affichait « acquise » meme avec des cartes en retard.
    private var freshness: Freshness.State {
        Freshness.state(cards: (page.cards ?? []).map {
            Freshness.CardState(dueAt: $0.dueAt, interval: $0.interval)
        })
    }

    private var freshnessLabel: String { freshness.rawValue }

    private var freshnessColor: Color {
        switch freshness {
        case .acquired:   K.success
        case .toReview:   K.fadedInk
        case .endangered: K.endangered
        case .draft:      K.pendingLine
        }
    }

    private var freshnessTextColor: Color {
        freshness == .draft ? K.inkSoft : freshnessColor
    }
}

/// Le papier pointille des apercus.
struct DottedPaper: View {
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 14
            let dot = Color(token: DesignTokens.Palette.hairline)
            var y: CGFloat = step / 2
            while y < size.height {
                var x: CGFloat = step / 2
                while x < size.width {
                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: 1.6, height: 1.6)),
                        with: .color(dot)
                    )
                    x += step
                }
                y += step
            }
        }
        .background(K.paperAlt)
    }
}

/// L'apercu d'une page : son ecriture, sa photo, ou le papier nu.
///
/// Partage entre la planche des cahiers et la liste ordonnee d'un cahier :
/// deux apercus differents pour la meme page seraient deroutants.
struct PagePreview: View {
    let page: Page

    #if os(iOS)
    @State private var slide: CGImage?
    /// On interroge la base plutot qu'un cache : un PDF importe a l'instant
    /// n'y serait pas encore, et sa vignette resterait blanche.
    @Query private var assets: [PDFAsset]
    #endif

    var body: some View {
        ZStack {
            DottedPaper()
            #if os(iOS)
            // La diapo d'un PDF : sans elle, toutes les pages importees
            // s'affichaient blanches dans le panneau.
            if let slide {
                Image(decorative: slide, scale: 1).resizable().scaledToFit()
            }
            #endif
            if let image = photo {
                image.resizable().scaledToFill()
            }
            if let image = ink {
                image.resizable().scaledToFit().padding(5)
            }
        }
        .clipped()
        #if os(iOS)
        .task(id: page.id) { await loadSlide() }
        #endif
    }

    #if os(iOS)
    private func loadSlide() async {
        guard slide == nil,
              let assetID = page.pdfAssetID,
              let index = page.pdfPageIndex,
              let fileName = assets.first(where: { $0.id == assetID })?.fileName
        else { return }
        let rendered = await Task.detached(priority: .utility) {
            PDFStore.render(fileName: fileName, pageIndex: index, width: 240)
        }.value
        slide = rendered
    }
    #endif

    private var photo: Image? {
        #if canImport(UIKit)
        guard let data = page.photo, let ui = UIImage(data: data) else { return nil }
        return Image(uiImage: ui)
        #else
        return nil
        #endif
    }

    private var ink: Image? {
        guard let data = page.drawing, let drawing = try? PKDrawing(data: data),
              !drawing.bounds.isEmpty else { return nil }
        let rendered = drawing.image(from: drawing.bounds, scale: 1)
        #if canImport(UIKit)
        return Image(uiImage: rendered)
        #else
        return Image(nsImage: rendered)
        #endif
    }
}
