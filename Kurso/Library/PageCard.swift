import SwiftUI
import PencilKit
import KursoCore
import KursoModels

/// Vignette d'une page.
///
/// L'apercu montre le vrai trace, jamais une police cursive : Caveat sert a
/// representer le manuscrit DANS LES MAQUETTES, l'app affiche l'encre reelle.
struct PageCard: View {
    let page: Page
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

    private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(page.createdAt, format: .dateTime.day().month(.twoDigits))
                    .font(KFont.mono(9))
                    .foregroundStyle(K.inkSoft)
                Spacer()
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(freshnessColor)
                    .frame(width: 9, height: 9)
            }
            Text(page.title.isEmpty ? "Sans titre" : page.title)
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

    /// Sans carte, une page est un brouillon : elle ne palit pas. On ne
    /// reproche pas de ne pas avoir fini.
    private var isDraft: Bool { (page.cards ?? []).isEmpty }

    private var freshnessColor: Color { isDraft ? K.pendingLine : K.success }
    private var freshnessTextColor: Color { isDraft ? K.inkSoft : K.success }
    private var freshnessLabel: String { isDraft ? "brouillon" : "acquise" }
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
