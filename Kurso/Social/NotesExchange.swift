import SwiftUI
import SwiftData
import KursoCore
import KursoModels

/// Demander les notes d'une séance où l'on n'était pas — et y répondre.
///
/// **Où vont les pages.** Le serveur ne transporte que la question : un nom de
/// cours, un jour, deux comptes. Ce qui contient du cours part d'appareil à
/// appareil, par la feuille de partage, où AirDrop est le premier choix. Le
/// §12 dit « aucune donnée de cours sur un serveur » et ajoute que la règle ne
/// bouge pas ; c'est exactement pour ça que l'échange se fait ici et pas là-bas.

/// Le bandeau qui constate une séance vide. Il ne compte rien, ne reproche
/// rien, et se referme définitivement d'un geste.
struct MissedClassBanner: View {
    let miss: MissedClass.Miss
    let mates: [Friend]
    var onAsk: (Friend) -> Void
    var onDismiss: () -> Void

    @State private var isPicking = false

    var body: some View {
        HStack(spacing: 14) {
            GribouView(mood: .idle, size: 58)
            VStack(alignment: .leading, spacing: 3) {
                Text(MissedClass.sentence(miss))
                    .font(KFont.display(18))
                    .foregroundStyle(K.ink)
                Text("Quelqu'un de ta classe peut t'envoyer les siennes.")
                    .font(KFont.body(12.5, weight: .bold))
                    .foregroundStyle(K.inkBody)
            }
            Spacer(minLength: 8)
            Button("Plus tard", action: onDismiss)
                .buttonStyle(.plain)
                .font(KFont.body(11.5, weight: .bold))
                .foregroundStyle(K.inkSoft)
            Button { isPicking = true } label: {
                Text("DEMANDER")
                    .font(KFont.body(11.5, weight: .extraBold))
                    .tracking(1)
                    .foregroundStyle(K.ink)
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(K.reward, in: Capsule())
                    .overlay(Capsule().strokeBorder(K.ink, lineWidth: 2.5))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(K.paperAlt, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(K.ink, lineWidth: 3))
        .sheet(isPresented: $isPicking) {
            AskPicker(miss: miss, mates: mates) { mate in
                isPicking = false
                onAsk(mate)
            } onCancel: {
                isPicking = false
            }
        }
    }
}

/// À qui demander. Une liste courte, des gens qu'on connaît : les amis, puis
/// les camarades de classe.
struct AskPicker: View {
    let miss: MissedClass.Miss
    let mates: [Friend]
    var onPick: (Friend) -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            DisplayText("Demander à qui ?", size: 24)
            Text(MissedClass.sentence(miss))
                .font(KFont.body(13, weight: .bold))
                .foregroundStyle(K.inkBody)

            if mates.isEmpty {
                Text("Personne dans ta classe pour l'instant. Ajoute un ami ou rejoins un groupe de classe.")
                    .font(KFont.body(13, weight: .bold))
                    .foregroundStyle(K.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(mates, id: \.id) { mate in
                        Button { onPick(mate) } label: {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(K.paper)
                                    .frame(width: 34, height: 34)
                                    .overlay(Circle().strokeBorder(K.ink, lineWidth: 2.2))
                                    .overlay(Text(mate.initial)
                                        .font(KFont.display(14))
                                        .foregroundStyle(K.ink))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(mate.displayName)
                                        .font(KFont.body(13.5, weight: .extraBold))
                                        .foregroundStyle(K.ink)
                                    Text(mate.isClassmateOnly ? "De ta classe" : "Ami")
                                        .font(KFont.body(11, weight: .bold))
                                        .foregroundStyle(K.inkSoft)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 10).padding(.horizontal, 14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(K.paperAlt, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .strokeBorder(K.ink.opacity(0.16), lineWidth: 2))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollIndicators(.hidden)

            Text("Seuls le nom du cours et la date partent. Tes propres pages ne bougent pas.")
                .font(KFont.body(11, weight: .bold))
                .foregroundStyle(K.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            Button("Annuler", action: onCancel)
                .buttonStyle(StickerButtonStyle(kind: .secondary))
        }
        .padding(24)
        .frame(maxWidth: 460, maxHeight: 520)
        .background(K.paper)
    }
}

/// Le bandeau de celui à qui on demande.
struct IncomingAskBanner: View {
    let ask: NoteAsk
    var onAccept: () -> Void
    var onDecline: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            GribouView(mood: .fier, size: 58)
            VStack(alignment: .leading, spacing: 3) {
                Text(MissedClass.invitation(from: ask.displayName,
                                            courseName: ask.courseName,
                                            day: MissedClass.day(ask.slotStart)))
                    .font(KFont.display(18))
                    .foregroundStyle(K.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(MissedClass.handoff)
                    .font(KFont.body(12.5, weight: .bold))
                    .foregroundStyle(K.inkBody)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button("Non", action: onDecline)
                .buttonStyle(.plain)
                .font(KFont.body(11.5, weight: .bold))
                .foregroundStyle(K.inkSoft)
            Button(action: onAccept) {
                Text("ENVOYER MES NOTES")
                    .font(KFont.body(11.5, weight: .extraBold))
                    .tracking(1)
                    .foregroundStyle(K.paperAlt)
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(K.success, in: Capsule())
                    .overlay(Capsule().strokeBorder(K.ink, lineWidth: 2.5))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(K.paperAlt, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(K.ink, lineWidth: 3))
    }
}

/// Rassemble les pages à envoyer : celles du cours demandé, écrites ce jour-là.
///
/// Pas le cahier entier : on répond à la question posée, et rien de plus.
enum NotesHandoff {

    static func pages(for ask: NoteAsk, in pages: [Page], calendar: Calendar = .current) -> [Page] {
        let day = calendar.startOfDay(for: ask.slotStart)
        return pages
            .filter { page in
                guard let name = page.course?.name, name == ask.courseName else { return false }
                return calendar.isDate(page.createdAt, inSameDayAs: day)
            }
            .sorted { $0.position < $1.position }
    }
}
