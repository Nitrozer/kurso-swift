# Kurso — paquet de passation

Document destiné à une session de développement.
Il contient ce que les maquettes ne peuvent pas montrer : le modèle de données, les algorithmes
chiffrés, le schéma de synchronisation et l'ordre de construction.

Les écrans de référence sont dans `Kurso Prototype.dc.html` (prototype cliquable, 15 écrans)
et `Kurso Dossier.dc.html` (document complet, pour les intentions).

**En cas de désaccord entre documents, l'ordre d'autorité est :**
1. ce fichier (`PASSATION.md`) — les valeurs et les algorithmes ;
2. `Kurso Prototype.dc.html` — le comportement observable ;
3. `Kurso Handoff.dc.html` — le même contenu que ce fichier, en un seul document partageable ;
4. tout le reste — des maquettes, jamais une spécification.

---

## 0 · Contexte technique

| | |
|---|---|
| Plateformes | iPadOS 18+, macOS 15+ |
| Langage | Swift 6, SwiftUI |
| Persistance | SwiftData |
| Synchronisation | CloudKit (base privée de l'utilisateur) |
| Écriture | PencilKit (`PKDrawing`, traits horodatés) |
| Reconnaissance | Vision (`VNRecognizeTextRequest`) + reconnaissance manuscrite PencilKit |
| Dates dans le texte | `NSDataDetector` |
| Emploi du temps | ICS (RFC 5545), parsé localement ; `EventKit` en source secondaire |
| Audio | AVFoundation, `AVAudioRecorder` en AAC 32 kbps mono |
| Compte | identité seule (Apple, Google, e-mail), aucune donnée de cours |

**Règle non négociable :** aucune donnée de cours ne sort de l'appareil autrement que par
CloudKit dans l'iCloud de l'utilisateur. C'est un argument produit, pas une préférence.

**Le compte est une exception délimitée** (écran 01 de l'onboarding). Il porte une
identité — de quoi retrouver l'utilisateur d'un appareil à l'autre et faire vivre la
ligue — et rien d'autre. Le contenu des cours ne transite jamais par lui : c'est ce
que dit l'écran de connexion lui-même, et c'est ce qui doit rester vrai.

---

## 1 · Modèle de données

> **Note d'implémentation.** Le code réel vit dans `Kurso/Models/`. Il suit ce
> modèle, avec trois adaptations imposées par SwiftData + CloudKit, qui ne
> changent pas la conception :
> 1. `Task` est renommée `Assignment` — `Task` masque `_Concurrency.Task` en Swift 6 ;
> 2. toute propriété a une valeur par défaut ou est optionnelle, et aucune contrainte
>    d'unicité n'est posée — CloudKit l'exige ;
> 3. chaque relation est optionnelle et déclare son inverse, ce qui ajoute quelques
>    propriétés d'inverse absentes d'ici (`Page.nextPage`, `Course.season`,
>    `Page.assignments`, `Page.recordings`).

### Course (matière)

```swift
@Model final class Course {
  var id: UUID
  var name: String            // "Algorithmique avancée"
  var colorToken: String      // "blue" | "green" | "pink" | "yellow" | "grey"
  var icsUID: String?         // identifiant de la série d'événements ICS
  var teacher: String?
  var archivedAt: Date?       // non nil = matière d'une saison archivée
  @Relationship var pages: [Page]
  @Relationship var terms: [GlossaryTerm]
}
```

### Page (l'unité centrale)

Une page est simultanément une prise de notes et un nœud de la carte.
**Il n'existe pas d'entité « nœud » séparée** — c'était une erreur de conception initiale.

```swift
@Model final class Page {
  var id: UUID
  var title: String              // reprise de la 1re ligne reconnue, éditable
  var titleWasEdited: Bool       // si true, ne plus jamais l'écraser
  var createdAt: Date
  var sessionEnd: Date?          // fin du créneau de cours, si rattachée
  var writingSeconds: Int        // temps réel stylet posé (pas temps d'écran)
  var drawing: Data?             // PKDrawing sérialisé
  var markdown: String           // volet Mac ; peut coexister avec le drawing
  var pdfAssetID: UUID?          // si la page annote un PDF déposé
  var pdfPageIndex: Int?
  @Relationship var course: Course?
  @Relationship var cards: [Card]
  @Relationship var previousPage: Page?   // lien chronologique = arête de la carte
  @Relationship var chapter: Chapter?
}
```

**`writingSeconds` est mesuré au stylet posé**, pas au temps d'écran : c'est lui qui pilote
l'usure de la mine de Gribou. Une page ouverte sans écrire ne compte pas.

### Card (flashcard)

```swift
@Model final class Card {
  var id: UUID
  var kind: CardKind             // .frontBack | .cloze | .imageOcclusion
  var question: String
  var answerText: String?        // texte tapé
  var answerDrawing: Data?       // PKDrawing : la ligne manuscrite, TELLE QUELLE
  var occlusionRect: CGRect?     // pour .imageOcclusion sur une diapo
  var sourceLineRange: Range<Int>?
  // état de répétition espacée
  var interval: Int              // en jours
  var ease: Double               // 1.3 … 2.8
  var dueAt: Date
  var lapses: Int                // nombre d'échecs cumulés
  var isInMistakeBook: Bool      // ≥ 2 échecs consécutifs
  @Relationship var page: Page?
}
```

**Le verso n'est jamais réécrit.** « inser° » reste « inser° ». Voir §4 sur les abréviations.

### Chapter (regroupement suggéré)

```swift
@Model final class Chapter {
  var id: UUID
  var name: String
  var isConfirmedByUser: Bool   // false = simple suggestion affichée en pointillés
  @Relationship var pages: [Page]
}
```

### Season (semestre)

```swift
@Model final class Season {
  var id: UUID
  var name: String              // "Semestre 5"
  var startsAt: Date
  var examDate: Date?           // pilote le mode partiel
  var closedAt: Date?
  // relevé figé à la clôture
  var finalAcquiredPercent: Double?
  var finalPagesCount: Int?
  var finalWritingHours: Double?
  var grade: Double?            // saisie facultative
  @Relationship var courses: [Course]
}
```

### League (ligue d'amis)

```swift
@Model final class League {
  var id: UUID
  var tier: String              // "HB" | "2B" | "4B" | "6B" — duretés de mine
  var weekStartsAt: Date        // remise à zéro le lundi 04:00
  @Relationship var members: [LeagueMember]
}

@Model final class LeagueMember {
  var id: UUID
  var displayName: String
  var initial: String
  var weeklyXP: Int             // XP de la semaine seulement
  var isMe: Bool
  var addedByUser: Bool         // TOUJOURS true : aucun inconnu
}
```

### Autres entités

- `Task` — titre, échéance, `sourceLineRange`, `wasProposed: Bool`, page liée.
- `GlossaryTerm` — terme, définition (extraite d'une ligne de l'étudiant), occurrences.
- `Abbreviation` — forme courte, forme longue, `source: .builtinList | .learnedFromMac | .userConfirmed`.
- `AudioRecording` — fichier, `startedAt`, et une table de correspondance
  `[(strokeID, offsetSeconds)]` construite à l'enregistrement.
- `Quest` — jour, type, cible, avancement.
- `PlayerState` — XP, niveau, série, **gommes restantes (0…5)**, `lastGommeRegenAt: Date`,
  gels restants, copeaux, `mineWear: Double` (0…1), `hasFullVersion: Bool`.

---

## 2 · Répétition espacée

SM-2 simplifié, volontairement lisible. Trois boutons seulement : *je savais*,
*à peu près*, *je séchais*.

```
ease initial      = 2.3
interval initiaux = 1 j, puis 3 j, puis interval × ease

je savais    → ease += 0.10 (max 2.8) ; interval = round(interval × ease)
à peu près   → ease -= 0.05           ; interval = round(interval × 1.2)
je séchais   → ease -= 0.20 (min 1.3) ; interval = 1 ; lapses += 1

interval plafonné à 180 jours.
dueAt = maintenant + interval jours, ramené à 04:00 heure locale.
```

**Carnet des ratés :** `lapses >= 2` ⇒ `isInMistakeBook = true`. À dix cartes dans le carnet,
il devient un « boss » ; le vider entièrement en une session donne une fiche or et remet
les compteurs `lapses` à 0.

**Après une session interrompue** (gommes épuisées, voir §9), les cartes non vues ne sont pas
pénalisées : `dueAt` reste inchangé. On perd le combo, jamais le travail.

---

## 3 · L'encre qui pâlit

C'est la mécanique signature. Une page a une **fraîcheur** de 0 à 1, calculée depuis
l'état de ses cartes, et jamais stockée — recalculée à l'affichage.

```swift
func freshness(of page: Page, now: Date) -> Double {
  guard !page.cards.isEmpty else { return 1.0 }   // brouillon : pas de pâlissement
  let scores = page.cards.map { card -> Double in
    let daysLate = now.timeIntervalSince(card.dueAt) / 86_400
    if daysLate <= 0 { return 1.0 }                       // pas encore due
    return max(0, 1 - daysLate / Double(max(card.interval, 1) * 2))
  }
  return scores.reduce(0, +) / Double(scores.count)
}
```

Seuils d'affichage (identiques dans l'app, la carte et l'export) :

| Fraîcheur | État | Couleur | Mot pour VoiceOver |
|---|---|---|---|
| ≥ 0.75 | acquise | `#17B26A` | « acquise » |
| 0.40 … 0.75 | à revoir | `#B8934A` | « à revoir » |
| < 0.40 | à sauver | `#E5484D` | « à sauver » |
| aucune carte | brouillon | contour pointillé | « brouillon » |

**L'encre du texte manuscrit lui-même** est atténuée à l'affichage par la même valeur :
`opacity = 0.35 + 0.65 × freshness`. Jamais en dessous de 0.35 — le texte doit rester lisible.

---

## 4 · Abréviations et titres, sans modèle de langage

Trois sources, dans cet ordre de priorité :

1. **Liste intégrée** (~120 entrées) : `ds, pcq, càd, bcp, tt, ts, qd, tjs, thm, dém, def, ex, cf, ∀, ∃, ⇒, ⇔, ≈, ∈`…
   Plus deux règles régulières :
   - suffixe `°` ⇒ essayer `-tion`, `-sion`, `-ment` et retenir la forme présente dans le glossaire ou le lexique français ;
   - tiret final ⇒ troncature, résolue par recherche de préfixe dans le vocabulaire de l'étudiant.
2. **Paires apprises du Mac.** Quand la même page contient un mot manuscrit abrégé et
   le mot complet tapé, la paire est enregistrée avec `source = .learnedFromMac`.
   Aucune interaction.
3. **Une question, une seule fois.** Si le mot reste ambigu *et* apparaît au moins trois fois,
   Gribou demande une fois, en fin de séance, jamais pendant l'écriture.
   `source = .userConfirmed`, et la question ne revient jamais.

**Le dictionnaire ne sert qu'à deux choses : la recherche, et les propositions de cartes.**
Il ne modifie jamais le contenu d'une page.

**Titre d'une page :** première ligne reconnue, tronquée à 60 caractères, sans ponctuation
finale. Si l'étudiant l'édite, `titleWasEdited = true` et on n'y retouche plus jamais.

---

## 5 · Détection des tâches

```
1. NSDataDetector extrait les dates de chaque ligne reconnue.
2. La ligne doit contenir un marqueur d'obligation :
   "à rendre", "pour le", "pour demain", "à faire", "DM", "devoir", "rendu",
   "exposé", "partiel", "contrôle", "TD", "TP".
3. Titre de la tâche = la ligne, nettoyée du marqueur et de la date.
4. Matière = celle de la page. Heure par défaut = 18:00 si absente.
5. La proposition apparaît en marge — jamais de tâche créée sans validation.
```

**Faux positifs :** si l'étudiant refuse trois propositions issues du même marqueur,
ce marqueur est désactivé pour lui. Sans réglage, sans message.

---

## 6 · Emploi du temps

- L'utilisateur colle une URL `.ics`. Parsing local, aucun envoi.
- On ne lit que : `DTSTART`, `DTEND`, `SUMMARY`, `LOCATION`, `UID`, `RRULE`.
- Regroupement en matières par similarité de `SUMMARY` (distance de Levenshtein
  normalisée > 0.85), puis validation par l'utilisateur — écran 03 de l'onboarding.
- Rafraîchissement au lancement, au maximum une fois par 6 h.
- **Après 5 jours sans réponse valide**, on affiche l'écran de lien expiré, une fois,
  sans bloquer quoi que ce soit. Les liens ADE/Hyperplanning changent chaque semestre.

**Rattachement page ↔ cours :** à l'ouverture d'une page, si un créneau est en cours
(tolérance ±15 min), la page s'y rattache automatiquement (`course`, `sessionEnd`),
et `previousPage` pointe vers la dernière page de la même matière.
C'est ce qui construit la carte sans aucune saisie.

---

## 7 · Audio collé à l'écriture

À l'enregistrement, pour chaque trait terminé, on note
`(stroke.identifier, recorder.currentTime)`.
À la lecture, toucher un mot cherche le trait le plus proche et démarre l'audio
2 secondes avant son horodatage — on veut le début de la phrase du prof, pas le milieu.

Compression AAC 32 kbps mono : environ 15 Mo pour deux heures. Stocké hors CloudKit
par défaut (fichier local + option d'inclusion), pour ne pas saturer l'iCloud de l'utilisateur.

---

## 8 · Synchronisation et conflits

CloudKit avec SwiftData, base privée. Le mode hors-ligne est le cas normal en amphi :
aucune alerte, une pastille grise, et une file d'attente locale.

**Conflit sur une page** (modifiée sur deux appareils hors-ligne) :

```
1. Les PKDrawing ne sont JAMAIS fusionnés automatiquement.
2. On conserve les deux versions et on présente l'écran de conflit
   (voir "01 Conflit de synchronisation").
3. Trois issues : garder A, garder B, ou créer deux pages liées.
4. Aucun trait n'est supprimé sans que l'utilisateur l'ait vu.
```

Le markdown, lui, se fusionne ligne par ligne quand les modifications ne se recouvrent pas.

---

## 9 · Gamification — valeurs exactes

```
XP
  carte juste                     15 × combo
  carte juste pendant le sprint   15 × combo × 2
  page écrite ≥ 10 min            30
  quête du jour                   30 … 50
  niveau n → n+1                  50 × n XP cumulés

Combo   ×1 départ → ×2 à 2 justes → ×3 à 4 → ×4 à 7 → ×6 si page sans faute
        une erreur ramène à ×1

Gommes  UNE SEULE MONNAIE, 5 au total, compteur GLOBAL — jamais remis à zéro
        par session. Une erreur en consomme une.
        À 0 → écran "Plus de gommes", la session s'arrête SANS pénaliser les dueAt.
        Régénération : +1 toutes les 4 h, plafonnée à 5.
        hasFullVersion == true ⇒ illimitées (le compteur n'est plus décrémenté).
        Écrire des notes ne coûte JAMAIS de gomme.

Série   +1 par jour avec ≥ 1 session terminée
        gels : max 2 en réserve, 1 utilisable par semaine
        GELÉE pendant le mode partiel (J-14 → examen)

Copeaux carte juste 8 · page finie 40 · nœud maîtrisé 120
        n'achètent QUE de l'apparence — jamais d'avance

Ligue   12 places maximum, uniquement des amis ajoutés par l'utilisateur.
        Grades = duretés de mine : HB → 2B → 4B → 6B.
        Les 3 premiers montent le dimanche 20:00.
        PERSONNE NE DESCEND : on monte, ou on reste.
        Les XP comptés sont ceux de la SEMAINE, remis à zéro le lundi 04:00.
        Une semaine sans rien faire ne sort pas de la ligue.
        Aucun classement public, aucun inconnu, aucune notification de rang.

Mine de Gribou
  mineWear = min(1, writingSecondsSinceLevel / 36_000)   // 10 h d'écriture
  remise à 0 par le clip taille_crayon au passage de niveau
```

**Mode partiel :** actif si `examDate - now <= 14 jours` (21 jours si la saison précédente
a fini avec des pages rouges). Effets : carte triée par fraîcheur croissante, sessions
portées à 20 cartes, tirage inversé une fois sur trois (réponse → question),
jeu en veille (pas de coffre, pas de ligue, pas d'animation de niveau), série gelée.

---

## 10 · Sons

Quatorze fichiers, tous enregistrés sur de vrais objets (taille-crayon, graphite, papier,
règle en bois). Trois variantes de hauteur par son, tirées au hasard pour éviter la lassitude.

| Événement | Son | Durée |
|---|---|---|
| Carte juste | mine sur papier | 90 ms |
| — au cran de combo n | **même son, +1 demi-ton par cran** | 90 ms |
| Erreur | frottement de gomme, mat, sans hauteur | 120 ms |
| Quête cochée | bois creux, note montante | 140 ms |
| Changement de page | page tournée, panoramique selon le geste | 180 ms |
| Passage de niveau | taille-crayon, deux tours de lame | 620 ms |
| Série perdue | souffle court — **seul son descendant de l'app** | 400 ms |
| Coffre ouvert | couvercle de bois + copeaux | 340 ms |
| Contrôle blanc | fond de salle vide à −38 dB | boucle |

**Règles :** fondu à 0 dès que le Pencil touche l'écran. Aucun son par défaut sur Mac.
Haptique sur iPad uniquement, aligné sur l'attaque du son.

---

## 11 · Ordre de construction

### Étape 1 — le socle outil *(sans ça, rien n'a de sens)*
Canevas PencilKit, cahiers, pages datées, volet markdown sur Mac, synchro CloudKit,
recherche manuscrite. **Aucune gamification à cette étape.**
Critère de sortie : prendre deux heures de notes en cours réel sans rien perdre.

### Étape 2 — le contexte
Import ICS, écran d'onboarding, rattachement page ↔ créneau, détection de tâches,
**annotation de PDF et masquage de diapos**. La moitié des cours sont des diapos :
c'est l'étape qui décide de l'adoption, pas une amélioration ultérieure.

### Étape 3 — la mémoire
Capture de cartes par le geste, répétition espacée, carte du semestre, encre qui pâlit,
session avec gommes et combo, carnet des ratés.
Critère de sortie : un semestre de test tient sans intervention manuelle.

### Étape 4 — le jeu et le confort
Niveaux, coffres, fiches à collectionner, copeaux, boutique, sons, Gribou animé (GLB),
sprint de fin de cours, audio synchronisé, widget, capture rapide Mac.
Puis mode partiel, export papier, relevé de saison et retour sur copie —
ces deux derniers ne servent qu'après un premier semestre complet.

---

## 11bis · Séparer la logique de l'interface

Kurso reste Apple-only en v1, mais **toute la logique métier doit vivre hors de SwiftUI**,
dans un module Swift pur sans aucun import UI :

- la répétition espacée (§2),
- le calcul de fraîcheur de l'encre (§3),
- la résolution des abréviations (§4),
- la détection des tâches (§5),
- le parsing ICS et le regroupement en matières (§6),
- toutes les valeurs de jeu : XP, combo, gommes, gels, `mineWear` (§9).

Deux raisons. Elle devient testable sans lancer l'app — et c'est la seule partie qui se
traduit sans douleur en Kotlin si le projet sort de l'écosystème Apple un jour. Tout le
reste (PencilKit, CloudKit, WidgetKit) serait de toute façon à réécrire.

**Ne pas mélanger** : aucun `import SwiftUI` dans ce module, aucun calcul de révision
dans une `View`.

---

## 12 · Ce qu'il ne faut pas coder

Cette liste a autant de valeur que le reste : chaque entrée est une décision prise,
pas un oubli.

- Pas de génération de cartes en masse depuis un PDF, ni de résumé automatique de cours.
- Pas de réécriture des notes de l'étudiant, jamais — abréviations comprises.
- Pas de dossiers, de tags ni d'arborescence à créer à la main : l'emploi du temps range.
- Pas de nœud verrouillé sur la carte : rien n'interdit de réviser ce qu'on veut.
- Pas de classement public permanent ; le duel de classe est ponctuel, la salle d'étude anonyme.
- Aucun achat qui fait progresser plus vite.
- Pas plus de deux notifications par jour, rien le week-end sans échéance.
- Pas de mascotte qui bouge pendant l'écriture ; six apparitions par session au maximum.
- Pas de pari de copeaux (mécanique retirée du projet : enjeu artificiel).
- Pas de télémétrie, pas de publicité, pas de revente de données.
- **Aucune donnée de cours sur un serveur.** Pages, cartes, audio, PDF : tout
  vit dans l'iCloud de l'utilisateur, jamais ailleurs. Cette règle-là ne bouge pas.

---

## 13 · Jetons de design

```
Marque          #3B5BFF      Graphite / encre   #131A33
Récompense      #FFD24D      Réussite           #17B26A
Alerte (fond)   #B3242A      Alerte (sur sombre) #FF8A8F
Papier          #F6F8FF      Papier alt         #FFFFFF
Gomme           #FF8FA3      Virole             #C9CFE0
Encre pâlie     #B8934A      Corps Gribou       #FFD24D

Typo   Baloo 2 (700/800) titres et chiffres
       Nunito (400…800) libellés et corps
       IBM Plex Mono métadonnées, heures
       Caveat rendu du manuscrit dans les maquettes uniquement

Autocollants   bordure 3 px #131A33, rayon 14 à 26 px,
               ombre dure 0 4px 0 #131A33 — jamais de flou
Mouvement      ressort, léger dépassement, rien au-delà de 600 ms
Interdits      verre translucide, dégradés, ombres floues, icônes de bibliothèque
```

Au-delà de la taille Dynamic Type « grande », les titres passent de Baloo 2 800
à Nunito 800. Aucun bloc n'a de hauteur fixe.
