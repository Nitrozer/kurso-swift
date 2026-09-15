import Foundation
import Observation

/// L'identite, et rien d'autre.
///
/// Ce client sait ouvrir une session et la retenir. Il ne transporte aucune
/// donnee de cours : les pages restent dans l'iCloud de l'utilisateur (§1).
/// Pas de SDK non plus — trois appels REST suffisent, et le projet reste sans
/// dependance externe.
@MainActor @Observable final class AuthClient {
    static let shared = AuthClient()

    struct Session: Codable, Sendable, Equatable {
        var accessToken: String
        var refreshToken: String
        var userID: String
        var email: String?
    }

    private(set) var session: Session?
    var isSignedIn: Bool { session != nil }

    private init() { session = Keychain.readSession() }

    enum Failure: LocalizedError, Equatable {
        case offline
        case rejected(String)
        case providerNotConfigured(String)
        case tooManyRequests

        var errorDescription: String? {
            switch self {
            case .offline:
                "Pas de réseau. Réessaie quand la connexion revient."
            case .tooManyRequests:
                "Trop de demandes d'affilée. Attends une minute."
            case .providerNotConfigured(let name):
                "La connexion avec \(name) n'est pas encore activée."
            case .rejected(let message):
                message
            }
        }
    }

    // MARK: Par adresse e-mail, avec un code

    /// Demande l'envoi d'un code a six chiffres.
    func sendCode(to email: String) async throws {
        _ = try await call("otp", body: [
            "email": email.trimmingCharacters(in: .whitespaces).lowercased(),
            "create_user": true,
        ])
    }

    /// Verifie le code recu et ouvre la session.
    func verifyCode(_ code: String, for email: String) async throws {
        let json = try await call("verify", body: [
            "email": email.trimmingCharacters(in: .whitespaces).lowercased(),
            "token": code.trimmingCharacters(in: .whitespaces),
            "type": "email",
        ])
        try adopt(json)
    }

    // MARK: Par identifiant Apple

    /// Echange le jeton d'identite d'Apple contre une session.
    func signInWithApple(idToken: String, nonce: String?) async throws {
        var body: [String: Any] = ["provider": "apple", "id_token": idToken]
        if let nonce { body["nonce"] = nonce }
        let json = try await call("token?grant_type=id_token", body: body)
        try adopt(json)
    }

    /// Renouvelle la session. Un jeton Supabase dure une heure : sans cela,
    /// la ligue se serait tue au bout d'un cours.
    @discardableResult
    func refresh() async -> Bool {
        guard let token = session?.refreshToken else { return false }
        do {
            let json = try await call("token", query: "grant_type=refresh_token", body: ["refresh_token": token])
            try adopt(json)
            return true
        } catch {
            // Un jeton de renouvellement refuse veut dire que la session est
            // finie pour de bon. On la retire plutot que de boucler dessus.
            if case Failure.rejected = error { signOut() }
            return false
        }
    }

    func signOut() {
        session = nil
        Keychain.clearSession()
    }

    // MARK: Rouages

    private func adopt(_ json: [String: Any]) throws {
        guard let access = json["access_token"] as? String,
              let refresh = json["refresh_token"] as? String,
              let user = json["user"] as? [String: Any],
              let id = user["id"] as? String
        else { throw Failure.rejected("Réponse inattendue du serveur.") }
        let new = Session(accessToken: access, refreshToken: refresh,
                          userID: id, email: user["email"] as? String)
        session = new
        Keychain.writeSession(new)
    }

    private func call(_ path: String, query: String? = nil, body: [String: Any]) async throws -> [String: Any] {
        // `appending(path:)` echappe le point d'interrogation : la requete de
        // renouvellement partait vers `token%3Fgrant_type=…` et revenait 404.
        var url = SupabaseConfig.url.appending(path: "auth/v1/\(path)")
        if let query {
            var parts = URLComponents(url: url, resolvingAgainstBaseURL: false)
            parts?.query = query
            url = parts?.url ?? url
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 20

        let data: Data, response: URLResponse
        do { (data, response) = try await URLSession.shared.data(for: request) }
        catch { throw Failure.offline }

        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else {
            if code == 429 { throw Failure.tooManyRequests }
            let raw = (json["msg"] ?? json["error_description"] ?? json["message"]) as? String
            // Supabase repond en anglais. On ne montre pas ca a l'utilisateur.
            switch json["error_code"] as? String {
            case "validation_failed" where raw?.localizedCaseInsensitiveContains("email") == true:
                throw Failure.rejected("Cette adresse ne semble pas valide.")
            case "otp_expired":
                throw Failure.rejected("Ce code est expiré ou incorrect.")
            case "over_email_send_rate_limit", "over_request_rate_limit":
                throw Failure.tooManyRequests
            case "email_provider_disabled":
                throw Failure.providerNotConfigured("l'adresse e-mail")
            default:
                if raw?.localizedCaseInsensitiveContains("provider is not enabled") == true {
                    throw Failure.providerNotConfigured("ce service")
                }
                throw Failure.rejected("Connexion refusée. Réessaie dans un instant.")
            }
        }
        return json
    }
}

/// Le trousseau, pas les reglages : un jeton de session n'a rien a faire
/// dans un fichier lisible.
private enum Keychain {
    private static let account = "supabase-session"

    static func readSession() -> AuthClient.Session? {
        var query = base
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return try? JSONDecoder().decode(AuthClient.Session.self, from: data)
    }

    static func writeSession(_ session: AuthClient.Session) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        SecItemDelete(base as CFDictionary)
        var item = base
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(item as CFDictionary, nil)
    }

    static func clearSession() { SecItemDelete(base as CFDictionary) }

    private static var base: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "app.kurso.auth",
         kSecAttrAccount as String: account]
    }
}
