import SwiftUI
import KursoCore
import KursoModels

/// Le releve de fin de semestre, d'apres `shots/saison-releve.png`.
///
/// Le seul ecran de Kurso sur fond sombre. C'est voulu : on ne ferme un
/// semestre qu'une fois, et l'inversion dit que ce moment n'est pas une page
/// de plus. La vraie ligne d'arrivee n'est pas un niveau, c'est l'etat de la
/// memoire le jour de l'examen — d'ou la carte, et non un score.
struct SeasonReportView: View {
    let season: Season
    let report: SeasonReport.Report
    var onArchive: () -> Void
    var onClose: () -> Void
    #if os(iOS)
    @State private var shared: ExportedFile?
    #endif

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            left
                .frame(maxWidth: .infinity, alignment: .topLeading)
            Rectangle()
                .fill(K.paperAlt.opacity(0.12))
                .frame(width: 1)
            right
                .frame(width: 330)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(K.ink)
        #if os(iOS)
        .sheet(item: $shared) { ShareSheet(url: $0.url) }
        #endif
    }

    // MARK: Colonne de gauche

    private var left: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Button(action: onClose) {
                    ChevronGlyph()
                        .stroke(K.paperAlt, style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
                        .frame(width: 12, height: 12)
                        .frame(width: 34, height: 34)
                        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .strokeBorder(K.paperAlt.opacity(0.35), lineWidth: 2))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Fermer le relevé")

                Text("SAISON TERMINÉE")
                    .font(KFont.body(11, weight: .extraBold))
                    .tracking(1.1)
                    .foregroundStyle(K.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(K.reward, in: Capsule())
                Text(meta)
                    .font(KFont.mono(10.5))
                    .tracking(1.1)
                    .foregroundStyle(K.paperAlt.opacity(0.5))
            }

            Text(SeasonReport.headline(report))
                .font(KFont.display(34))
                .foregroundStyle(K.paperAlt)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 16)

            Text("C'est ça, la vraie ligne d'arrivée : pas un niveau à atteindre, mais l'état de ta mémoire le jour où on t'interroge. La carte s'archive ici, et une carte vierge repart ensuite.")
                .font(KFont.body(13, weight: .bold))
                .foregroundStyle(K.paperAlt.opacity(0.62))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 520, alignment: .leading)
                .padding(.top, 12)

            // Le panneau remplit la colonne, comme sur la maquette : le
            // laisser epouser son contenu laissait un grand vide sombre.
            mapPanel
                .padding(.top, 20)
                .frame(maxHeight: .infinity, alignment: .top)
        }
        .padding(.trailing, 26)
    }

    /// La carte au jour du partiel : une pastille par noeud.
    private var mapPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("LA CARTE, AU JOUR DU PARTIEL")
                .font(KFont.mono(10))
                .tracking(1.2)
                .foregroundStyle(K.paperAlt.opacity(0.45))

            if report.states.isEmpty {
                Text("Aucune page écrite ce semestre.")
                    .font(KFont.body(13, weight: .bold))
                    .foregroundStyle(K.paperAlt.opacity(0.5))
            } else {
                FlowDots(states: report.states)
                legend
                Text(caption)
                    .font(KFont.body(12, weight: .bold))
                    .foregroundStyle(K.paperAlt.opacity(0.45))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(K.paperAlt.opacity(0.04), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(K.paperAlt.opacity(0.16), lineWidth: 1.5))
    }

    /// Le mot accompagne toujours la couleur (§3) : rien ne repose sur la
    /// seule teinte.
    private var legend: some View {
        // Seules les categories peuplees : « 0 a consolider » prenait deux
        // lignes pour ne rien dire.
        HStack(spacing: 20) {
            ForEach(shownLegend, id: \.0) { state, label in
                legendItem(state, count: report.count(state), label: label)
            }
        }
    }

    private var shownLegend: [(Freshness.State, String)] {
        let all: [(Freshness.State, String)] = [
            (.acquired, "acquises"),
            (.toReview, "à consolider"),
            (.endangered, "presque effacées"),
            (.draft, "brouillons"),
        ]
        let shown = all.filter { report.count($0.0) > 0 }
        // Une carte entierement vide doit quand meme dire ce qu'elle mesure.
        return shown.isEmpty ? [all[0]] : shown
    }

    private func legendItem(_ state: Freshness.State, count: Int, label: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .strokeBorder(Self.tint(state), lineWidth: 2.5)
                .frame(width: 13, height: 13)
            Text("\(count) \(label)")
                .font(KFont.body(11.5, weight: .bold))
                .foregroundStyle(K.paperAlt.opacity(0.62))
        }
    }

    private var caption: String {
        let endangered = report.count(.endangered)
        guard endangered > 0 else {
            return "\(report.pages) pages écrites, aucune laissée de côté."
        }
        return "\(report.pages) pages écrites, dont \(endangered) laissée\(endangered > 1 ? "s" : "") presque effacée\(endangered > 1 ? "s" : "")."
    }

    // MARK: Colonne de droite

    private var right: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("LE RELEVÉ")
                .font(KFont.mono(10))
                .tracking(1.2)
                .foregroundStyle(K.paperAlt.opacity(0.45))
                .padding(.bottom, 6)

            row("Carte acquise au partiel", "\(report.acquiredPercent) %", highlighted: true)
            row("Pages écrites", "\(report.pages)")
            row("Heures d'écriture", "\(hours) h")
            row("Cartes revues", "\(report.cardsReviewed)")
            row("Plus longue série", "\(report.longestStreak) j")
            row("Fiches or", "\(report.goldFiches) sur \(report.totalFiches)", highlighted: true)

            mineCard.padding(.top, 18)
            Spacer(minLength: 20)

            Button("ARCHIVER ET OUVRIR \(SeasonReport.nextName(after: season.name).uppercased())") { onArchive() }
                .buttonStyle(StickerButtonStyle(kind: .primary))
            Button(action: share) {
                Text("PARTAGER LE RELEVÉ")
                    .font(KFont.display(15))
                    .foregroundStyle(K.paperAlt)
                    .padding(.vertical, 13)
                    .frame(maxWidth: .infinity)
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(K.paperAlt.opacity(0.35), lineWidth: 2.5))
            }
            .buttonStyle(.plain)
            .padding(.top, 8)

            Text("Les cahiers archivés restent lisibles et cherchables pour toujours.")
                .font(KFont.body(10.5, weight: .bold))
                .foregroundStyle(K.paperAlt.opacity(0.4))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
        }
        .padding(.leading, 26)
    }

    /// « 0,4 h » et non « 0.4 h » : la virgule est le separateur decimal ici.
    /// Partage le releve. On passe par un fichier texte : `ShareSheet` prend
    /// une URL, et ca evite d'en ecrire une seconde version.
    private func share() {
        #if os(iOS)
        let text = SeasonReport.shareText(report, seasonName: season.name)
        let name = season.name.isEmpty ? "Relevé Kurso" : "Relevé — \(season.name)"
        let url = URL.temporaryDirectory.appending(path: "\(name).txt")
        guard (try? text.write(to: url, atomically: true, encoding: .utf8)) != nil else { return }
        shared = ExportedFile(url: url)
        #endif
    }

    private var hours: String {
        report.writingHours.rounded() == report.writingHours
            ? String(Int(report.writingHours))
            : report.writingHours.formatted(.number.precision(.fractionLength(1)))
    }

    private func row(_ label: String, _ value: String, highlighted: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(label)
                    .font(KFont.body(12.5, weight: .bold))
                    .foregroundStyle(K.paperAlt.opacity(0.66))
                Spacer(minLength: 8)
                Text(value)
                    .font(KFont.display(17))
                    .foregroundStyle(highlighted ? K.reward : K.paperAlt)
            }
            .padding(.vertical, 13)
            Rectangle().fill(K.paperAlt.opacity(0.1)).frame(height: 1)
        }
    }

    private var mineCard: some View {
        HStack(spacing: 12) {
            GribouView(mood: .fier, size: 72)
            VStack(alignment: .leading, spacing: 2) {
                Text("Mine changée \(report.mineChanges) fois")
                    .font(KFont.display(15))
                    .foregroundStyle(K.paperAlt)
                Text("Un taille-crayon par niveau franchi.")
                    .font(KFont.body(11.5, weight: .bold))
                    .foregroundStyle(K.paperAlt.opacity(0.55))
            }
            Spacer(minLength: 0)
        }
        .padding(13)
        .background(K.paperAlt.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var meta: String {
        let from = season.startsAt.formatted(.dateTime.month(.abbreviated)).uppercased()
        let to = Date.now.formatted(.dateTime.month(.abbreviated).year()).uppercased()
        return "\(season.name.uppercased()) · \(from) → \(to)"
    }

    static func tint(_ state: Freshness.State) -> Color {
        switch state {
        case .acquired:   K.success
        case .toReview:   K.reward
        case .endangered: K.endangered
        case .draft:      K.paperAlt.opacity(0.28)
        }
    }
}

/// Les pastilles, qui passent a la ligne toutes seules.
private struct FlowDots: View {
    let states: [Freshness.State]

    var body: some View {
        // Une grille adaptative plutot qu'un HStack : vingt-quatre noeuds
        // tiennent sur deux lignes, quatre-vingts sur sept.
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 28, maximum: 28), spacing: 8, alignment: .leading)],
                  alignment: .leading, spacing: 8) {
            ForEach(Array(states.enumerated()), id: \.offset) { _, state in
                Circle()
                    .fill(SeasonReportView.tint(state).opacity(0.85))
                    .frame(width: 26, height: 26)
                    .overlay(Circle().strokeBorder(SeasonReportView.tint(state), lineWidth: 2.5))
                    .accessibilityLabel(state.rawValue)
            }
        }
    }
}
