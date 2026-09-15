import Foundation

/// Le code ami : sept caracteres qu'on se donne a voix haute dans un couloir.
///
/// Rien d'autre ne circule pour s'ajouter. Pas de repertoire, pas de numero,
/// pas de recherche par nom : on ne tombe sur personne par hasard, et personne
/// ne tombe sur vous. C'est la meme decision que le §12 sur le classement
/// public — Kurso ne met jamais un inconnu en face de l'utilisateur.
public enum FriendCode {

    /// Alphabet de Crockford : les trente-deux signes qui restent quand on
    /// retire ceux qui se confondent a l'oral comme a l'ecrit (I, L, O, U).
    /// Un code se dicte une fois ; il ne doit pas se re-taper.
    public static let alphabet = Array("0123456789ABCDEFGHJKMNPQRSTVWXYZ")

    public static let length = 6

    /// Fabrique le code d'un compte. Deterministe : le meme identifiant rend
    /// toujours le meme code, sur n'importe quel appareil et a n'importe quel
    /// lancement — donc rien a stocker pour le retrouver.
    ///
    /// `salt` sert au serveur : si l'index unique refuse le code parce qu'un
    /// autre compte l'a deja, on rappelle avec le sel suivant.
    public static func make(from accountID: String, salt: Int = 0) -> String {
        var hash = digest("\(accountID)#\(salt)")
        var out = ""
        for _ in 0..<length {
            out.append(alphabet[Int(hash % UInt64(alphabet.count))])
            hash /= UInt64(alphabet.count)
        }
        return out
    }

    /// `ABC123` devient `ABC-123`. Le tiret n'existe qu'a l'ecran : il coupe
    /// le code en deux moities qu'on retient le temps de les taper.
    public static func format(_ code: String) -> String {
        let clean = normalise(code)
        guard clean.count == length else { return clean }
        let cut = clean.index(clean.startIndex, offsetBy: length / 2)
        return "\(clean[..<cut])-\(clean[cut...])"
    }

    /// Ramene ce qui a ete tape a la forme canonique : majuscules, sans tiret
    /// ni espace, et les jumeaux ramenes sur le signe retenu — un `O` dicte
    /// devient le zero, un `I` ou un `l` deviennent le un.
    public static func normalise(_ typed: String) -> String {
        var out = ""
        for character in typed.uppercased() {
            switch character {
            case "O": out.append("0")
            case "I", "L": out.append("1")
            case "-", " ", ".", "_": continue
            default: out.append(character)
            }
        }
        return out
    }

    public static func isValid(_ typed: String) -> Bool {
        let clean = normalise(typed)
        return clean.count == length && clean.allSatisfy(alphabet.contains)
    }

    /// FNV-1a. Surtout pas `hashValue` : Swift le sale a chaque lancement du
    /// processus, le code aurait change a chaque ouverture de l'application.
    private static func digest(_ text: String) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return hash
    }
}
