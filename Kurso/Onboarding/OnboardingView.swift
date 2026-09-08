import SwiftUI
import SwiftData
import KursoCore
import KursoModels

/// La mise en route, en quatre temps (§11 etape 2).
///
/// Il n'y a pas de compte a creer : §12 l'interdit — pas de serveur, pas de
/// telemetrie. L'identite est celle de l'iCloud deja present sur l'appareil,
/// et le prenom demande ici ne sert qu'a ecrire « Salut … » en haut du jour.
struct OnboardingView: View {
    @Environment(\.modelContext) private var context

    private enum Step: String { case signIn, name, timetable, ready }
    @State private var step: Step = {
        #if DEBUG
        if let i = ProcessInfo.processInfo.arguments.firstIndex(of: "-onboardingStep"),
           i + 1 < ProcessInfo.processInfo.arguments.count,
           let requested = Step(rawValue: ProcessInfo.processInfo.arguments[i + 1]) {
            return requested
        }
        #endif
        // Une session deja ouverte ne se redemande pas.
        return AuthClient.shared.isSignedIn ? .name : .signIn
    }()
    @State private var name = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // L'ecran de connexion porte son propre titre, plein cadre.
            if step != .timetable && step != .signIn { header }
            switch step {
            case .signIn:    SignInView { step = .name }
            case .name:      nameStep
            case .timetable: TimetableOnboardingView(onFinish: { step = .ready })
            case .ready:     readyStep
            }
        }
        // Une colonne de lecture : etire sur toute la largeur d'un iPad, le
        // texte devient illisible. L'ecran de connexion, lui, est plein cadre —
        // il a sa propre mise en page en deux panneaux.
        .frame(maxWidth: step == .signIn ? .infinity : 620, alignment: .topLeading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(K.paper)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            MetaText("Étape \(number) sur 4")
            DisplayText(title, size: 32)
        }
        .padding(.horizontal, 32)
        .padding(.top, 30)
        .padding(.bottom, 20)
    }

    private var number: Int {
        switch step {
        case .signIn: 1
        case .name: 2
        case .timetable: 3
        case .ready: 4
        }
    }

    private var title: String {
        switch step {
        case .signIn:    "Kurso"
        case .name:      "Comment on t'appelle ?"
        case .timetable: "Ton emploi du temps"
        case .ready:     name.isEmpty ? "C'est prêt." : "C'est prêt, \(name)."
        }
    }

    // MARK: 02 — le prenom

    private var nameStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Uniquement pour te dire bonjour en haut de l'écran. Rien n'est envoyé nulle part.")
                .font(KFont.body(13.5, weight: .bold))
                .foregroundStyle(K.ink.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)

            TextField("Ton prénom", text: $name)
                .textFieldStyle(.plain)
                .font(KFont.display(26))
                .foregroundStyle(K.ink)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .sticker(fill: K.paperAlt, radius: 16)
                #if os(iOS)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                #endif

            Spacer(minLength: 0)

            HStack(spacing: 12) {
                Button("Passer") { name = ""; step = .timetable }
                    .buttonStyle(StickerButtonStyle(kind: .secondary))
                Button("Continuer") { step = .timetable }
                    .buttonStyle(StickerButtonStyle(kind: .brand))
                    .disabled(trimmedName.isEmpty)
                    // Un bouton inerte doit se voir : sans prenom, il attend.
                    .opacity(trimmedName.isEmpty ? 0.45 : 1)
            }
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 28)
    }

    // MARK: 04 — c'est parti

    private var readyStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Ouvre une page pendant un cours : elle se rangera toute seule dans la bonne matière. Le reste vient au fur et à mesure.")
                .font(KFont.body(15, weight: .bold))
                .foregroundStyle(K.ink)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Button("Ouvrir Kurso") { finish() }
                .buttonStyle(StickerButtonStyle(kind: .brand))
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 28)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// L'etat de jeu est cree ici : c'est le premier moment ou il a un sens.
    private func finish() {
        let player = (try? context.fetch(FetchDescriptor<PlayerState>()).first) ?? {
            let new = PlayerState()
            context.insert(new)
            return new
        }()
        player.displayName = trimmedName
        player.hasCompletedOnboarding = true
        try? context.save()
    }
}
