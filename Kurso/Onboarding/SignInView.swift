import SwiftUI
import AuthenticationServices
import CryptoKit
import KursoCore

/// Ecran 01 de l'onboarding : ouvrir une session.
///
/// Le compte porte une identite, pas des cours. La ligne du bas le dit a
/// l'utilisateur, et c'est une promesse qui engage le reste de l'app (§1).
struct SignInView: View {
    var onSignedIn: () -> Void

    @State private var auth = AuthClient.shared
    @State private var step: Step = .choose
    @State private var email = ""
    @State private var code = ""
    @State private var isBusy = false
    @State private var message: String?
    @State private var appleNonce = ""

    private enum Step { case choose, askEmail, askCode }

    var body: some View {
        // La maquette est pensee en paysage. En portrait, le panneau bleu
        // ecraserait la colonne de texte : on le retire plutot que de couper
        // les mots en deux.
        GeometryReader { geo in
            let wide = geo.size.width > 1_000
            HStack(spacing: 0) {
                leftPanel(wide: wide)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(K.ink)
                if wide {
                    rightPanel
                        .frame(width: geo.size.width * 0.34)
                        .frame(maxHeight: .infinity)
                        .background(K.brand)
                }
            }
        }
        .ignoresSafeArea()
    }

    // MARK: Le panneau sombre

    private func leftPanel(wide: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)

            if !wide {
                GribouView(mood: .fier, size: 164)
                    .padding(.bottom, 18)
            }

            HStack(spacing: 14) {
                Text("K")
                    .font(KFont.display(38))
                    .foregroundStyle(K.paperAlt)
                    .frame(width: 60, height: 60)
                    .background(K.brand, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                Text("Kurso").font(KFont.display(34)).foregroundStyle(K.paperAlt)
            }

            Text("Tes cours, tes notes, ta mémoire.")
                .font(KFont.display(wide ? 46 : 36))
                .foregroundStyle(K.paperAlt)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 30)
                .frame(maxWidth: 440, alignment: .leading)

            Text("Écris au Pencil pendant le cours. Le reste — le classement, les révisions, les rappels — se fait à partir de ce que tu as écrit.")
                .font(KFont.body(15, weight: .bold))
                .foregroundStyle(K.paperAlt.opacity(0.66))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)
                .frame(maxWidth: 400, alignment: .leading)

            Group {
                switch step {
                case .choose:   providers
                case .askEmail: emailField
                case .askCode:  codeField
                }
            }
            .frame(maxWidth: 400, alignment: .leading)
            .padding(.top, 34)

            if let message {
                Text(message)
                    .font(KFont.body(12.5, weight: .bold))
                    .foregroundStyle(K.paperAlt)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .frame(maxWidth: 400, alignment: .leading)
                    .background(K.alertBg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.top, 16)
            }

            HStack(spacing: 9) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(K.success)
                Text("Tes notes restent sur ton iCloud. Kurso n'héberge aucun cours.")
                    .font(KFont.body(12, weight: .bold))
                    .foregroundStyle(K.paperAlt.opacity(0.5))
            }
            .padding(.top, 30)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, wide ? 56 : 40)
        .frame(maxWidth: wide ? .infinity : 520, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: wide ? .leading : .center)
    }

    private var providers: some View {
        VStack(spacing: 11) {
            SignInWithAppleButton(.continue) { request in
                appleNonce = Self.freshNonce()
                request.requestedScopes = [.email]
                request.nonce = Self.sha256(appleNonce)
            } onCompletion: { result in
                handleApple(result)
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Button { signInWithGoogle() } label: {
                Text("Continuer avec Google")
                    .font(KFont.body(15.5, weight: .extraBold))
                    .foregroundStyle(K.paperAlt)
                    .lineLimit(1).minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(K.paperAlt.opacity(0.28), lineWidth: 2.5))
            }
            .buttonStyle(.plain)

            Button { step = .askEmail; message = nil } label: {
                Text("Utiliser une adresse e-mail")
                    .font(KFont.body(14, weight: .extraBold))
                    .foregroundStyle(K.paperAlt.opacity(0.55))
                    .lineLimit(1).minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
        }
    }

    private var emailField: some View {
        VStack(alignment: .leading, spacing: 11) {
            TextField("ton@email.fr", text: $email)
                .textFieldStyle(.plain)
                .font(KFont.body(16, weight: .bold))
                .foregroundStyle(K.ink)
                .padding(.horizontal, 16).padding(.vertical, 15)
                .background(K.paperAlt, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                #endif
                .autocorrectionDisabled()

            darkButton(isBusy ? "Envoi…" : "Recevoir un code", enabled: email.contains("@") && !isBusy) {
                Task { await send() }
            }
            backLink("Revenir aux autres moyens") { step = .choose; message = nil }
        }
    }

    private var codeField: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("Code envoyé à \(email)")
                .font(KFont.body(13, weight: .bold))
                .foregroundStyle(K.paperAlt.opacity(0.66))

            TextField("12345678", text: $code)
                .textFieldStyle(.plain)
                .font(KFont.mono(20))
                .foregroundStyle(K.ink)
                .padding(.horizontal, 16).padding(.vertical, 15)
                .background(K.paperAlt, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif

            darkButton(isBusy ? "Vérification…" : "Entrer", enabled: code.count >= 8 && !isBusy) {
                Task { await verify() }
            }
            backLink("Changer d'adresse") { step = .askEmail; code = ""; message = nil }
        }
    }

    private func darkButton(_ title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(KFont.body(15.5, weight: .extraBold))
                .foregroundStyle(K.paperAlt)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(K.brand, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
    }

    private func backLink(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(KFont.body(13, weight: .extraBold))
                .foregroundStyle(K.paperAlt.opacity(0.55))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }

    // MARK: Le panneau bleu

    private var rightPanel: some View {
        ZStack {
            DotGrid()
            GribouView(mood: .fier, size: 284)
        }
    }

    // MARK: Actions

    private func send() async {
        isBusy = true; message = nil
        do { try await auth.sendCode(to: email); step = .askCode }
        catch { message = (error as? LocalizedError)?.errorDescription ?? "Échec de l'envoi." }
        isBusy = false
    }

    private func verify() async {
        isBusy = true; message = nil
        do { try await auth.verifyCode(code, for: email); onSignedIn() }
        catch { message = (error as? LocalizedError)?.errorDescription ?? "Code refusé." }
        isBusy = false
    }

    private func handleApple(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure:
            // Sans la capacite « Sign in with Apple », le systeme refuse avant
            // meme d'afficher la feuille. Le dire plutot que de rester muet.
            message = "Connexion Apple indisponible. La capacité n'est pas encore activée sur le compte développeur."
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let data = credential.identityToken,
                  let token = String(data: data, encoding: .utf8)
            else { message = "Apple n'a pas renvoyé de jeton."; return }
            Task {
                isBusy = true
                do { try await auth.signInWithApple(idToken: token, nonce: appleNonce); onSignedIn() }
                catch { message = (error as? LocalizedError)?.errorDescription ?? "Connexion refusée." }
                isBusy = false
            }
        }
    }

    private func signInWithGoogle() {
        // Le fournisseur Google n'est pas encore declare cote Supabase : il
        // demande un identifiant OAuth que seul le proprietaire du projet cree.
        message = "La connexion Google n'est pas encore activée sur le projet."
    }

    // MARK: Nonce

    private static func freshNonce() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

/// La trame de points du panneau bleu (ecran 01).
private struct DotGrid: View {
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 28, r: CGFloat = 1.4
            var y: CGFloat = step / 2
            while y < size.height {
                var x: CGFloat = step / 2
                while x < size.width {
                    context.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                                 with: .color(.white.opacity(0.16)))
                    x += step
                }
                y += step
            }
        }
    }
}
