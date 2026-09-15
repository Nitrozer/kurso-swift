# Kurso

A class notebook for iPad and Mac. You write with the Pencil during the lecture;
the filing, the revision and the reminders are all built from what you wrote.

[Français](README.md) · **English**

---

## What it is

A student has no time to file their notes. The timetable already knows which
class happens when — so the timetable does the filing. All that's left is to
write.

From the written pages, the app builds:

- **revision cards**, offered at the end of the lecture, never bulk-generated
  from a PDF;
- a **memory map** where every page is a node whose ink fades as you forget;
- **reminders** — two a day at most, nothing at the weekend without a deadline;
- an **end-of-term report**, and a post-mortem after an exam.

The game layer — XP, streak, erasers, shavings, chests, a league among friends —
never buys progress. Shavings pay for appearance only.

## The rule everything answers to

> **No course data on a server.** Pages, cards, audio, PDFs: everything lives in
> the user's own iCloud, nowhere else.

The account is a bounded exception: it carries an identity — enough to find
someone across devices and to run the league — and nothing more. Even asking a
classmate for the notes of a lecture you missed only carries the *name* of the
course and the date; the pages themselves travel device to device over AirDrop.

## The screens

| | |
|---|---|
| **Day** | the lecture happening now, the streak, the quests, the league |
| **Notebooks** | one notebook per subject, filed by the timetable |
| **Memory** | the term's map, one node per page |
| **Review** | today's session, cards sorted by freshness |
| **Cards** | the revision sheets drawn from the pages |

Plus the account screen (the rail's avatar) and the league.

## Architecture

```
KursoCore/Sources/KursoCore     43 files · pure logic, no UI import
KursoCore/Sources/KursoModels   19 SwiftData models
KursoCore/Tests                 45 files · 51 suites · 359 tests
Kurso/                          77 files, one folder per screen
supabase/migrations/            the little server schema there is
```

The split is not decorative. All the logic — spaced repetition, ink fading,
abbreviation resolution, task detection, ICS parsing, game values, league rules —
lives in a pure Swift module. It can be tested without launching the app, and
it is the only part that would survive leaving the Apple ecosystem.

**No external dependencies.** No Supabase SDK: three REST calls are enough.

## Build and run

Xcode 26+, Swift 6, iPadOS 18+ / macOS 15+.

```bash
xcodebuild -project Kurso.xcodeproj -scheme Kurso \
  -destination 'platform=iOS Simulator,name=iPad Air 11-inch (M4)' build

xcodebuild -project Kurso.xcodeproj -scheme Kurso \
  -destination 'platform=macOS' build

cd KursoCore && swift test
```

## Seeing the screens with something in them

An empty database shows nothing. Launch flags, `DEBUG` only, fill the app and
open a given screen:

```bash
xcrun simctl launch <device> com.enzomerfeld.kurso \
  -seedDemoData -seedLeague -startTab day
```

| Flag | Effect |
|---|---|
| `-seedDemoData` | courses, written pages, cards, a timetable |
| `-startTab <day\|notebooks\|memory\|review\|cards>` | opens that tab |
| `-seedLeague` | a populated league, a class group, a missed lecture |
| `-openLeague` / `-leaguePage <league\|friends\|classes>` | opens the league on that tab |
| `-examSoon` / `-examOver` | exam mode, then the post-mortem |
| `-simulateChest` | a chest to open |

`-seedDemoData` is idempotent: uninstall first to replay the seed.

> The iPad is used **in landscape**. Screenshots taken in portrait give a false
> impression of the screens.

## What goes over the network

One Supabase project, five tables prefixed `kurso_`:

| Table | What it holds |
|---|---|
| `kurso_profiles` | a first name, a friend code, a grade, this week's XP |
| `kurso_friendships` | who asked whom, and where it stands |
| `kurso_groups` / `kurso_group_members` | the class groups |
| `kurso_note_asks` | a course name, a date, two accounts |

There is no column a page could fit in, and the client has no function to send
one. Everything is behind RLS: an account sees only itself, its friends, and the
people in its groups. You find someone only by knowing their full friend code —
no search by name, no suggestions, no listing.

The `anon` key sits in the source: that is its nature, it ships in every client
and opens only what RLS allows. The `service_role` key never comes near this
repository.

## What isn't done

- **The 14 sounds** — to be recorded from real objects, not synthesised.
- **The widget and Mac quick capture** — App Groups needs a paid Apple Developer
  account.
- **CloudKit and Sign in with Apple** are off for the same reason. The schema is
  already compliant (defaults everywhere, optional relationships with inverses),
  so turning them on needs no migration.
- **The social layer has never run against a real account.** It compiles and the
  screens were checked in the simulator, but no actual round trip with the
  server has been possible.

## The contract

`PASSATION.md` is the authority (in French): fifteen sections giving the data
model, the numbered algorithms, the exact game values, and — §12 — the list of
what must **not** be built. Every entry on that list is a decision taken, not an
oversight.
