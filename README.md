# Kurso

Carnet de cours pour iPad et Mac. On écrit au Pencil pendant le cours ; le
classement, les révisions et les rappels se font à partir de ce qui a été écrit.

**Français** · [English](README.en.md)

---

## Ce que c'est

Un étudiant n'a pas le temps de ranger ses notes. L'emploi du temps sait déjà
quel cours a lieu à quelle heure — c'est donc lui qui range. Il ne reste qu'à
écrire.

À partir des pages, l'application fabrique :

- des **cartes de révision** proposées à la fin du cours, jamais générées en
  masse depuis un PDF ;
- une **carte de la mémoire** où chaque page est un nœud dont l'encre pâlit à
  mesure qu'on oublie ;
- des **rappels** — deux par jour au maximum, rien le week-end sans échéance ;
- un **relevé de fin de semestre**, et un retour sur copie après un partiel.

Le jeu — XP, série, gommes, copeaux, coffres, ligue entre amis — n'achète jamais
d'avance. Les copeaux ne paient que de l'apparence.

## La règle qui commande tout

> **Aucune donnée de cours sur un serveur.** Pages, cartes, audio, PDF : tout
> vit dans l'iCloud de l'utilisateur, jamais ailleurs.

Le compte est une exception délimitée : il porte une identité — de quoi
retrouver quelqu'un d'un appareil à l'autre et faire vivre la ligue — et rien
d'autre. Même la demande de notes d'une séance manquée ne transporte que le
*nom* du cours et la date ; les pages, elles, partent d'appareil à appareil par
AirDrop.

## Les écrans

| | |
|---|---|
| **Jour** | le cours en train d'avoir lieu, la série, les quêtes, la ligue |
| **Cahiers** | un cahier par matière, rangé par l'emploi du temps |
| **Mémoire** | la carte du semestre, un nœud par page |
| **Réviser** | la session du jour, cartes triées par fraîcheur |
| **Fiches** | les fiches de révision tirées des pages |

Plus l'écran du compte (avatar du rail) et la ligue.

## Architecture

```
KursoCore/Sources/KursoCore     43 fichiers · logique pure, aucun import UI
KursoCore/Sources/KursoModels   19 modèles SwiftData
KursoCore/Tests                 45 fichiers · 51 suites · 359 tests
Kurso/                          77 fichiers, un dossier par écran
supabase/migrations/            le peu de schéma serveur qu'il y a
```

La séparation n'est pas décorative. Toute la logique — répétition espacée,
pâleur de l'encre, résolution des abréviations, détection des tâches, parsing
ICS, valeurs de jeu, règles de la ligue — vit dans un module Swift pur. Elle se
teste sans lancer l'application, et c'est la seule partie qui survivrait à une
sortie de l'écosystème Apple.

**Aucune dépendance externe.** Pas de SDK Supabase : trois appels REST suffisent.

## Compiler et lancer

Xcode 26+, Swift 6, iPadOS 18+ / macOS 15+.

```bash
xcodebuild -project Kurso.xcodeproj -scheme Kurso \
  -destination 'platform=iOS Simulator,name=iPad Air 11-inch (M4)' build

xcodebuild -project Kurso.xcodeproj -scheme Kurso \
  -destination 'platform=macOS' build

cd KursoCore && swift test
```

## Voir les écrans pleins

Une base vide ne montre rien. Des drapeaux de lancement, actifs en `DEBUG`
seulement, remplissent l'application et ouvrent un écran précis :

```bash
xcrun simctl launch <appareil> com.enzomerfeld.kurso \
  -seedDemoData -seedLeague -startTab day
```

| Drapeau | Effet |
|---|---|
| `-seedDemoData` | des cours, des pages écrites, des cartes, un emploi du temps |
| `-startTab <day\|notebooks\|memory\|review\|cards>` | ouvre cet onglet |
| `-seedLeague` | une ligue peuplée, un groupe de classe, une séance manquée |
| `-openLeague` / `-leaguePage <league\|friends\|classes>` | ouvre la ligue sur cet onglet |
| `-examSoon` / `-examOver` | le mode partiel, puis le retour sur copie |
| `-simulateChest` | un coffre à ouvrir |

`-seedDemoData` est idempotent : pour rejouer la graine, désinstaller d'abord.

> L'iPad s'utilise **en paysage**. Les captures prises en portrait donnent une
> fausse idée des écrans.

## Ce qui passe par le réseau

Un projet Supabase, cinq tables préfixées `kurso_` :

| Table | Ce qu'elle contient |
|---|---|
| `kurso_profiles` | un prénom, un code ami, un grade, les XP de la semaine |
| `kurso_friendships` | qui a demandé qui, et où ça en est |
| `kurso_groups` / `kurso_group_members` | les groupes de classe |
| `kurso_note_asks` | le nom d'un cours, une date, deux comptes |

Aucune colonne où une page tiendrait, et le client n'a aucune fonction pour en
envoyer une. Tout est en RLS : un compte ne voit que lui-même, ses amis, et les
gens de ses groupes. On ne trouve quelqu'un qu'en connaissant son code ami en
entier — pas de recherche par prénom, pas de suggestions, aucune liste.

La clé `anon` est dans les sources : c'est sa nature, elle part dans chaque
client et n'ouvre que ce que RLS autorise. La clé `service_role` n'approche
jamais ce dépôt.

## Ce qui n'est pas fait

- **Les 14 sons** — à enregistrer sur de vrais objets, pas à synthétiser.
- **Le widget et la capture rapide sur Mac** — App Groups exige un compte
  Apple Developer payant.
- **CloudKit et Sign in with Apple** sont désactivés pour la même raison. Le
  schéma est déjà conforme (valeurs par défaut partout, relations optionnelles
  avec inverse) : l'activation se fera sans migration.
- **La couche sociale n'a jamais tourné avec un vrai compte.** Elle compile et
  les écrans ont été vérifiés au simulateur, mais aucun aller-retour réel avec
  le serveur n'a pu être fait.

## Le contrat

`PASSATION.md` fait autorité : quinze sections qui donnent le modèle de données,
les algorithmes chiffrés, les valeurs de jeu exactes, et — §12 — la liste de ce
qu'il ne faut **pas** coder. Chaque entrée de cette liste est une décision prise,
pas un oubli.
