---
id: t-010-id-locale
title: Add Indonesian locale support to the app
status: ready
owner: -
wave: 2
priority: high
depends_on: t-001-windows-paths
areas: [app]
---

# Objective

Make the app display in Indonesian when the device locale is Indonesian, with
English as the fallback. This is Phase 2 of the Mise-Kal roadmap.

# Why

Mise-Kal targets Indonesian restaurants. A POS that a waiter cannot read in
their own language is a POS that gets used wrong, and a wrong order is a
business problem, not a translation problem.

This is also the first task that touches user-facing strings across the whole
app, so it establishes the pattern every later feature will follow.

# Scope

**In scope**

- Setting up localization infrastructure (`flutter_localizations`, ARB files or
  the project's chosen mechanism).
- Extracting user-facing strings from the POS, KDS and Manager shells.
- Indonesian translations for everything extracted.
- Number, currency and date formatting that respects the locale.

**Out of scope**

- Translating the server's hook messages. Those are developer-facing.
- Adding languages beyond Indonesian and English.
- Changing any layout. A translated string that overflows is a bug to report,
  not to fix by shrinking the font.

# Files and areas you may touch

```
app/lib/features/        allowed
app/lib/core/theme/      read-only
app/lib/data/            read-only
app/pubspec.yaml         allowed (localization dependencies)
app/l10n.yaml            allowed (create)
```

**Never touch**

- `server/` — the backend is language-neutral by design.
- Any money computation. Currency *display* may change; how a total is
  calculated may not.

# Dependencies

`t-001-windows-paths` merged, because running the app on Windows is how you will
verify the translations.

# Acceptance criteria

- [ ] With the device locale set to `id`, the POS, KDS and Manager shells render
      in Indonesian.
- [ ] With any other locale, they render in English exactly as before.
- [ ] Currency and number formatting follow the locale (thousands separators,
      decimal marks).
- [ ] No user-facing string remains hardcoded in the three shells.
- [ ] No string is machine-translated without review — a mistranslated button is
      worse than an English one.
- [ ] Existing tests still pass, and a test asserts that the Indonesian and
      English ARB files have identical key sets.

# Test requirement

```bash
.harness/scripts/test.sh --agent NAME --app
```

Plus a new test that the locale files have matching keys — a missing key is
otherwise invisible until a user hits that screen.

# Commit requirement

- Subject: `feat(i18n): ...`
- Extraction and translation may be separate commits if that keeps each one
  reviewable.

# Report requirement

List any string whose Indonesian translation is uncertain, and any screen where
the Indonesian text overflows its layout. Both need a human decision.
