import Foundation

/// La resolution des abreviations (§4), sans modele de langage.
///
/// Trois sources, dans cet ordre : la liste integree, les paires apprises du
/// Mac, puis la reponse donnee une fois par l'etudiant. Deux regles regulieres
/// completent la liste.
///
/// **Le dictionnaire ne sert qu'a deux choses : la recherche et les
/// propositions de cartes. Il ne modifie JAMAIS le contenu d'une page.** C'est
/// la ligne du §4, et elle rejoint le §12 : on ne reecrit pas les notes.
public enum Abbreviations {

    /// D'ou vient une resolution, par priorite decroissante.
    public enum Source: String, Sendable, Equatable, CaseIterable {
        case builtinList
        case rule
        case learnedFromMac
        case userConfirmed
    }

    public struct Resolution: Equatable, Sendable {
        public let short: String
        public let long: String
        public let source: Source

        public init(short: String, long: String, source: Source) {
            self.short = short
            self.long = long
            self.source = source
        }
    }

    /// La liste integree. Des abreviations d'etudiant, pas un dictionnaire.
    public static let builtin: [String: String] = [
        // Liaisons et adverbes
        "ds": "dans", "pcq": "parce que", "pq": "pourquoi", "càd": "c'est-à-dire",
        "cad": "c'est-à-dire", "bcp": "beaucoup", "tt": "tout", "ts": "tous",
        "tte": "toute", "ttes": "toutes", "qd": "quand", "qq": "quelque",
        "qqs": "quelques", "qqch": "quelque chose", "qqn": "quelqu'un",
        "tjs": "toujours", "tjrs": "toujours", "jms": "jamais", "ms": "mais",
        "dc": "donc", "ap": "après", "av": "avant", "ss": "sous", "sr": "sur",
        "ns": "nous", "vs": "vous", "pr": "pour", "par ex": "par exemple",
        "càp": "c'est-à-peu-près", "env": "environ", "svt": "souvent",
        "gal": "général", "gale": "générale", "galement": "généralement",
        "ie": "c'est-à-dire", "eg": "par exemple", "etc": "et cetera",
        // Mathematiques et raisonnement
        "thm": "théorème", "th": "théorème", "dém": "démonstration",
        "dem": "démonstration", "def": "définition", "déf": "définition",
        "prop": "proposition", "cor": "corollaire", "lem": "lemme",
        "ex": "exemple", "exo": "exercice", "cf": "confer", "rq": "remarque",
        "ccl": "conclusion", "hyp": "hypothèse", "dvpt": "développement",
        "dvp": "développement", "eq": "équation", "éq": "équation",
        "fct": "fonction", "fonct": "fonction", "vect": "vecteur",
        "mat": "matrice", "esp": "espace", "ens": "ensemble", "elt": "élément",
        "élt": "élément", "ppté": "propriété", "ppte": "propriété",
        "cv": "convergence", "cvg": "convergence", "div": "divergence",
        "intg": "intégrale", "int": "intégrale", "dér": "dérivée", "der": "dérivée",
        "lim": "limite", "min": "minimum", "max": "maximum", "sup": "supremum",
        "inf": "infimum", "abs": "absolu", "qcq": "quelconque",
        // Symboles
        "∀": "pour tout", "∃": "il existe", "∄": "il n'existe pas",
        "⇒": "implique", "⇔": "équivaut à", "→": "tend vers", "↦": "associe à",
        "≈": "environ égal à", "≃": "équivalent à", "≠": "différent de",
        "≤": "inférieur ou égal à", "≥": "supérieur ou égal à",
        "∈": "appartient à", "∉": "n'appartient pas à", "⊂": "inclus dans",
        "∪": "union", "∩": "intersection", "∅": "ensemble vide",
        "∑": "somme", "∏": "produit", "∞": "infini", "∂": "dérivée partielle",
        "∇": "gradient", "±": "plus ou moins", "⊥": "orthogonal à",
        "ℕ": "entiers naturels", "ℤ": "entiers relatifs", "ℚ": "rationnels",
        "ℝ": "réels", "ℂ": "complexes",
        // Sciences et gestion
        // « ds » vaut deja « dans » plus haut : en prise de notes il est mille
        // fois plus frequent que « devoir surveille », et un litteral de
        // dictionnaire avec doublon plante au premier acces.
        "tp": "travaux pratiques", "td": "travaux dirigés", "cm": "cours magistral",
        "dm": "devoir maison", "qcm": "questionnaire à choix multiples",
        "ex.": "exemple", "nb": "nota bene", "pb": "problème", "sol": "solution",
        "temp": "température", "press": "pression", "vol": "volume",
        "conc": "concentration", "réact": "réaction", "react": "réaction",
        "exp": "expérience", "obs": "observation", "mes": "mesure",
        "moy": "moyenne", "ect": "écart-type", "proba": "probabilité",
        "stat": "statistique", "alg": "algorithme", "algo": "algorithme",
        "cplx": "complexité", "itér": "itération", "iter": "itération",
        "récur": "récurrence", "recur": "récurrence", "struct": "structure",
    ]

    /// Les terminaisons essayees derriere un `°`, dans cet ordre.
    public static let degreeEndings = ["tion", "sion", "ment"]

    // MARK: Resolution

    /// Resout un mot abrege.
    ///
    /// - Parameters:
    ///   - word: le mot tel qu'il est ecrit.
    ///   - learned: les paires apprises du Mac ou confirmees, par forme courte.
    ///   - vocabulary: le vocabulaire de l'etudiant, pour les deux regles.
    ///
    /// L'ordre de priorite est inverse de celui du §4 pour une raison : ce que
    /// l'etudiant a confirme lui-meme prime sur une liste generique, et une
    /// paire vue sur SA page prime sur une regle devinee.
    public static func resolve(
        _ word: String,
        learned: [String: Resolution] = [:],
        vocabulary: [String] = []
    ) -> Resolution? {
        let key = normalise(word)
        guard !key.isEmpty else { return nil }

        if let known = learned[key] { return known }
        if let long = builtin[key] {
            return Resolution(short: key, long: long, source: .builtinList)
        }
        if let long = byRule(key, vocabulary: vocabulary) {
            return Resolution(short: key, long: long, source: .rule)
        }
        return nil
    }

    /// Les deux regles regulieres du §4.
    public static func byRule(_ word: String, vocabulary: [String]) -> String? {
        let key = normalise(word)

        // Suffixe ° : on essaie -tion, -sion, -ment, et on retient la forme
        // presente dans le vocabulaire de l'etudiant.
        if key.hasSuffix("°") {
            let stem = String(key.dropLast())
            guard !stem.isEmpty else { return nil }
            let known = Set(vocabulary.map(normalise))
            for ending in degreeEndings where known.contains(stem + ending) {
                return stem + ending
            }
            return nil
        }

        // Tiret final : troncature, resolue par recherche de prefixe.
        if key.hasSuffix("-") {
            let stem = String(key.dropLast())
            guard stem.count >= 2 else { return nil }
            let matches = vocabulary
                .map(normalise)
                .filter { $0.hasPrefix(stem) && $0.count > stem.count }
            // Une seule suite possible, sinon on ne devine pas.
            let unique = Set(matches)
            return unique.count == 1 ? unique.first : nil
        }

        return nil
    }

    // MARK: Apprentissage

    /// Les paires apprises d'une page : un mot abrege manuscrit, et sa forme
    /// complete tapee sur le Mac dans la meme page. Aucune interaction.
    public static func learnedPairs(handwritten: String, typed: String) -> [Resolution] {
        let shorts = words(handwritten).filter { isAbbreviationShaped($0) }
        let longs = Set(words(typed).filter { $0.count > 3 })
        guard !shorts.isEmpty, !longs.isEmpty else { return [] }

        var found: [String: String] = [:]
        for short in shorts where builtin[short] == nil {
            let stem = short.hasSuffix("°") || short.hasSuffix("-") ? String(short.dropLast()) : short
            guard stem.count >= 2 else { continue }
            // Deux facons d'ecrire court : tronquer (« polyn- »), ou ne
            // garder que les consonnes (« cplx » pour « complexite »). La
            // seconde est la plus repandue en amphi, et le prefixe seul ne la
            // voyait pas.
            let candidates = longs.filter {
                $0.count > stem.count && ($0.hasPrefix(stem) || isSkeleton(stem, of: $0))
            }
            // Une seule forme complete possible, sinon on n'apprend rien.
            if candidates.count == 1, let long = candidates.first {
                found[short] = long
            }
        }
        return found
            .map { Resolution(short: $0.key, long: $0.value, source: .learnedFromMac) }
            .sorted { $0.short < $1.short }
    }

    /// `stem` est-il le squelette de `word` : ses lettres, dans l'ordre, en
    /// commencant par la meme ?
    ///
    /// La premiere lettre commune est exigee : sans elle, « ts » vaudrait
    /// « mathematiques » et on apprendrait n'importe quoi.
    static func isSkeleton(_ stem: String, of word: String) -> Bool {
        guard let first = stem.first, word.first == first else { return false }
        var remaining = Substring(word)
        for letter in stem {
            guard let index = remaining.firstIndex(of: letter) else { return false }
            remaining = remaining[remaining.index(after: index)...]
        }
        return true
    }

    /// Combien de fois un mot doit apparaitre avant qu'on ose demander.
    public static let askThreshold = 3

    /// Les mots qui restent ambigus et reviennent assez pour meriter LA
    /// question — une seule, en fin de seance, jamais pendant l'ecriture.
    public static func worthAsking(
        in text: String,
        learned: [String: Resolution] = [:],
        vocabulary: [String] = [],
        alreadyAsked: Set<String> = []
    ) -> [String] {
        var counts: [String: Int] = [:]
        for word in words(text) where isAbbreviationShaped(word) {
            counts[word, default: 0] += 1
        }
        return counts
            .filter { short, count in
                count >= askThreshold
                    && !alreadyAsked.contains(short)
                    && resolve(short, learned: learned, vocabulary: vocabulary) == nil
            }
            .keys
            .sorted()
    }

    // MARK: Les deux seuls usages autorises (§4)

    /// Le texte d'une page **augmente** de la forme longue de ses abreviations,
    /// pour la recherche seule.
    ///
    /// On AJOUTE, on ne remplace pas : la page n'est jamais reecrite (§4, §12).
    /// Chercher « théorème » trouve ainsi une page qui n'ecrit que « thm »,
    /// sans qu'un seul caractere de la page ait bouge.
    public static func searchableText(
        _ text: String,
        learned: [String: Resolution] = [:],
        vocabulary: [String] = []
    ) -> String {
        let expansions = Set(
            words(text)
                .filter(isAbbreviationShaped)
                .compactMap { resolve($0, learned: learned, vocabulary: vocabulary)?.long }
        )
        guard !expansions.isEmpty else { return text }
        return text + " " + expansions.sorted().joined(separator: " ")
    }

    /// La forme lisible d'un terme propose en carte, abreviations deployees.
    ///
    /// Le recto d'une carte qui demande « thm de Rolle ? » se lit mal ; la
    /// page, elle, garde son « thm ».
    public static func expandedTerm(
        _ term: String,
        learned: [String: Resolution] = [:],
        vocabulary: [String] = []
    ) -> String {
        term
            .components(separatedBy: " ")
            .map { piece in
                guard isAbbreviationShaped(piece),
                      let resolved = resolve(piece, learned: learned, vocabulary: vocabulary)
                else { return piece }
                return resolved.long
            }
            .joined(separator: " ")
    }

    // MARK: Outils

    /// Ce a quoi ressemble une abreviation : court, ou marque d'un ° ou d'un
    /// tiret final. Un mot ordinaire n'a rien a faire ici.
    public static func isAbbreviationShaped(_ word: String) -> Bool {
        let key = normalise(word)
        guard !key.isEmpty else { return false }
        if key.hasSuffix("°") || key.hasSuffix("-") { return true }
        guard key.count <= 5 else { return false }
        // Au moins une lettre : « 12 » n'est pas une abreviation.
        return key.contains { $0.isLetter }
    }

    /// Les mots d'un texte, ponctuation retiree sauf ° et tiret final.
    public static func words(_ text: String) -> [String] {
        text
            .components(separatedBy: CharacterSet(charactersIn: " \n\t\r,;:!?()[]{}\"«»…"))
            .map(normalise)
            .filter { !$0.isEmpty }
    }

    /// Minuscules, et on ne garde le point final que s'il fait partie du mot.
    public static func normalise(_ word: String) -> String {
        var trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        while let last = trimmed.last, last == "." || last == "'" {
            trimmed.removeLast()
        }
        return trimmed
    }
}
