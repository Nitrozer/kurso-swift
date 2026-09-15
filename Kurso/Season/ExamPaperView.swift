import SwiftUI
import KursoCore
import KursoModels

/// Le retour sur copie, d'apres `shots/saison-copie.png`.
///
/// Ce que l'etudiant a rate, rapproche de l'etat de ses pages la veille du
/// partiel. Ce n'est pas un bilan : ce sont des reglages pour le semestre
/// suivant, et le ton compte autant que le contenu — pas une lecon de morale.
struct ExamPaperView: View {
    let paper: ExamPaper
    let misses: [ExamReview.Miss]
    let pageTitles: [UUID: String]
    var onOpenPage: (UUID) -> Void
    var onClose: () -> Void

    private var verdict: ExamReview.Verdict {
        ExamReview.verdict(misses: misses, grade: paper.grade, outOf: paper.outOf)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                HStack(alignment: .top, spacing: 22) {
                    missList.frame(maxWidth: .infinity, alignment: .topLeading)
                    sideColumn.frame(width: 340)
                }
                .padding(.top, 22)
            }
            .padding(28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(K.paper)
    }

    // MARK: En-tete

    private var header: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Button(action: onClose) {
                        ChevronGlyph()
                            .stroke(K.ink, style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
                            .frame(width: 12, height: 12)
                            .frame(width: 34, height: 34)
                            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .strokeBorder(K.ink, lineWidth: 2.5))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Fermer le retour sur copie")

                    Text(meta)
                        .font(KFont.mono(10.5))
                        .tracking(1.1)
                        .foregroundStyle(K.inkSoft)
                }

                DisplayText(ExamReview.headline(verdict), size: 31)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Tu as saisi ta note et coché les exercices ratés. Kurso les rapproche de l'état de tes pages la veille de l'examen — c'est la seule chose qu'aucune autre app ne peut faire, parce qu'elle connaît les deux.")
                    .font(KFont.body(13, weight: .bold))
                    .foregroundStyle(K.inkBody)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 640, alignment: .leading)
            }
            Spacer(minLength: 0)
            gradeCard
        }
    }

    private var gradeCard: some View {
        HStack(spacing: 16) {
            VStack(spacing: 0) {
                Text(number(paper.grade))
                    .font(KFont.display(34))
                    .foregroundStyle(K.paperAlt)
                Text("/ \(number(paper.outOf))")
                    .font(KFont.body(12, weight: .bold))
                    .foregroundStyle(K.paperAlt.opacity(0.6))
            }
            Rectangle().fill(K.paperAlt.opacity(0.2)).frame(width: 1, height: 42)
            VStack(alignment: .leading, spacing: 3) {
                Text("Ta note")
                    .font(KFont.body(12.5, weight: .extraBold))
                    .foregroundStyle(K.paperAlt)
                // La moyenne de promo demanderait un serveur et dix etudiants :
                // le §12 garde tout sur l'appareil, donc on ne la promet pas.
                Text("Gardée sur cet iPad,\njamais partagée.")
                    .font(KFont.body(11.5, weight: .bold))
                    .foregroundStyle(K.paperAlt.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(K.ink, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: Les ratés

    private var missList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("LES EXERCICES RATÉS, ET LES PAGES QUI LES PORTAIENT")
                .font(KFont.mono(10))
                .tracking(1.1)
                .foregroundStyle(K.inkSoft)

            if misses.isEmpty {
                Text("Aucun raté coché. Rien à rapprocher.")
                    .font(KFont.body(13, weight: .bold))
                    .foregroundStyle(K.inkSoft)
                    .padding(.vertical, 8)
            } else {
                ForEach(misses) { missCard($0) }
                if let conclusion = ExamReview.conclusion(verdict) { banner(conclusion) }
            }
        }
    }

    private func missCard(_ miss: ExamReview.Miss) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                Text("−\(number(miss.points)) PT")
                    .font(KFont.body(11, weight: .extraBold))
                    .tracking(0.6)
                    // Le jaune ne porte jamais de texte clair : toujours l'encre.
                    .foregroundStyle(miss.points >= 2 ? K.paperAlt : K.ink)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(pillTint(miss.points), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(K.ink, lineWidth: 2.5))

                VStack(alignment: .leading, spacing: 3) {
                    Text(miss.label)
                        .font(KFont.display(17))
                        .foregroundStyle(K.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    if miss.kind == .courseQuestion {
                        Text("Question de cours")
                            .font(KFont.body(12, weight: .bold))
                            .foregroundStyle(K.inkSoft)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(16)

            Rectangle().fill(K.ink.opacity(0.1)).frame(height: 1)
            pageRow(miss)
        }
        .background(K.paperAlt, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(K.ink, lineWidth: 3))
    }

    /// La page qui portait l'exercice, et son etat la veille.
    private func pageRow(_ miss: ExamReview.Miss) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(dotTint(miss.stateAtExam).opacity(0.85))
                .frame(width: 15, height: 15)
                .overlay(Circle().strokeBorder(dotTint(miss.stateAtExam), lineWidth: 2.5))

            VStack(alignment: .leading, spacing: 2) {
                Text(pageLabel(miss))
                    .font(KFont.body(13, weight: .extraBold))
                    .foregroundStyle(K.ink)
                Text(stateLine(miss))
                    .font(KFont.body(12, weight: .bold))
                    .foregroundStyle(K.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)

            if let pageID = miss.pageID {
                Button("Rouvrir la page") { onOpenPage(pageID) }
                    .font(KFont.body(12, weight: .extraBold))
                    .foregroundStyle(K.brand)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(K.brand.opacity(0.1), in: Capsule())
                    .buttonStyle(.plain)
            }
        }
        .padding(16)
    }

    private func banner(_ text: String) -> some View {
        HStack(spacing: 14) {
            GribouView(mood: .inquiet, size: 44)
            Text(text)
                .font(KFont.display(16))
                .foregroundStyle(K.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(K.reward, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(K.ink, lineWidth: 3))
    }

    // MARK: Colonne de droite

    private var sideColumn: some View {
        VStack(spacing: 14) {
            adjustmentsCard
            privacyCard
        }
    }

    private var adjustmentsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Ce que Kurso en retient")
                    .font(KFont.display(19))
                    .foregroundStyle(K.paperAlt)
                Text("Pas une leçon de morale : un réglage.")
                    .font(KFont.body(12.5, weight: .bold))
                    .foregroundStyle(K.paperAlt.opacity(0.62))
            }

            if verdict.adjustments.isEmpty {
                Text("Rien à régler : ce qui est parti ne venait pas de pages laissées de côté.")
                    .font(KFont.body(12.5, weight: .bold))
                    .foregroundStyle(K.paperAlt.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(Array(verdict.adjustments.enumerated()), id: \.offset) { index, item in
                    adjustmentRow(index + 1, item)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(K.ink, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func adjustmentRow(_ number: Int, _ item: ExamReview.Adjustment) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Text("\(number)")
                .font(KFont.body(11, weight: .extraBold))
                .foregroundStyle(K.paperAlt)
                .frame(width: 21, height: 21)
                .background(K.brand, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(KFont.body(13, weight: .extraBold))
                    .foregroundStyle(K.paperAlt)
                Text(item.detail)
                    .font(KFont.body(12, weight: .bold))
                    .foregroundStyle(K.paperAlt.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var privacyCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Ta note reste chez toi")
                .font(KFont.display(18))
                .foregroundStyle(K.paperAlt)
            Text("La saisie est facultative, jamais réclamée, jamais partagée, jamais comparée à un nom. Elle ne quitte pas cet iPad.")
                .font(KFont.body(12.5, weight: .bold))
                .foregroundStyle(K.paperAlt.opacity(0.62))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(K.ink, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: Details

    private var meta: String {
        let day = paper.examDate.formatted(.dateTime.day().month(.wide))
        let course = paper.courseName.isEmpty ? "PARTIEL" : paper.courseName.uppercased()
        return "\(course) · PARTIEL DU \(day.uppercased())"
    }

    private func pageLabel(_ miss: ExamReview.Miss) -> String {
        guard let id = miss.pageID, let title = pageTitles[id], !title.isEmpty else {
            return "Aucune page rattachée"
        }
        return title
    }

    /// Ce que la page disait d'elle-meme la veille.
    private func stateLine(_ miss: ExamReview.Miss) -> String {
        guard let state = miss.stateAtExam else {
            return "Pas de photographie : le partiel a précédé cette mesure."
        }
        let days = miss.daysSinceReview.map { " — \($0) jour\($0 > 1 ? "s" : "") sans révision" } ?? ""
        switch state {
        case .acquired:   return "Acquise la veille\(days)"
        case .toReview:   return "À consolider la veille\(days)"
        case .endangered: return "Presque effacée la veille\(days)"
        case .draft:      return "Brouillon : aucune carte n'en était tirée"
        }
    }

    /// Plus le raté coute cher, plus la pastille chauffe.
    private func pillTint(_ points: Double) -> Color {
        if points >= 3 { return K.endangered }
        if points >= 2 { return K.flame }
        return K.reward
    }

    private func dotTint(_ state: Freshness.State?) -> Color {
        switch state {
        case .acquired:   K.success
        case .toReview:   K.reward
        case .endangered: K.endangered
        case .draft, nil: K.inkSoft.opacity(0.5)
        }
    }

    private func number(_ value: Double) -> String {
        value == value.rounded()
            ? String(Int(value))
            : value.formatted(.number.precision(.fractionLength(1)))
    }
}
