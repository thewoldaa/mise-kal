---
id: t-001-windows-paths
title: Audit Windows path and shell portability across the repo
status: ready
owner: -
wave: 1
priority: high
depends_on: -
areas: [server, app, docs, installer]
---

# Objective

Establish, with evidence, everywhere Mise-Kal does not work or behaves
differently on Windows compared with macOS/Linux, and fix the ones that block
development.

The harness already made the backend suites runnable on Windows. This task is
about the rest of the repository: build scripts, path handling, and the
assumptions baked into `installer/` and `app/scripts/`.

# Why

Upstream is developed and documented on macOS. Its only packaging target so far
is a DMG. Mise-Kal's Phase 1 goal is a stabilised, tested, installable system,
and the development machine is Windows — so "does this actually work here" has
to be answered before any new feature is built on top.

A path bug found now costs minutes. The same bug found after Phase 2's
localization work costs a rewrite.

# Scope

**In scope**

- Auditing every shell script, build script and path construction for
  Windows-hostile assumptions (hardcoded `/tmp`, `realpath -m`, `flock`,
  GNU-only `sed`/`date` flags, `/` separators in C#-free code, case-sensitivity).
- Fixing the ones that block running or building on Windows.
- Documenting the ones that are acceptable (macOS-only packaging, for example).

**Out of scope**

- Writing the Windows installer. That is a separate task.
- Rewriting upstream's suites. They are patched at run time by the harness on
  purpose, so upstream stays mergeable.

# Files and areas you may touch

```
server/scripts/          allowed
server/fetch_pocketbase.sh  allowed
app/scripts/             allowed
installer/               allowed
docs/developing.md       allowed
.harness/scripts/        read-only (report problems, do not patch)
```

# Dependencies

None.

# Acceptance criteria

- [ ] A written inventory of every Windows portability issue found, each with
      the file, the line, and whether it blocks development or is cosmetic.
- [ ] Every blocking issue fixed, with the fix explained in the commit body.
- [ ] `./server/scripts/dev.sh` starts PocketBase on Windows from Git Bash.
- [ ] `server/fetch_pocketbase.sh` downloads the correct Windows asset.
- [ ] No upstream test suite is modified in place.
- [ ] `docs/developing.md` gains a Windows section that says exactly what a
      Windows developer needs installed and what they should expect not to work.

# Test requirement

```bash
.harness/scripts/test.sh --agent NAME --all
```

All seven suites must pass. The suites are the evidence that path changes did
not break anything.

# Commit requirement

- One commit per distinct fix, or one commit for the whole audit if the fixes
  are trivially small. Do not mix an audit's documentation with unrelated code
  changes.
- Subject: `fix(portability): ...` or `docs(developing): ...`.

# Report requirement

State the inventory in the report, including the issues you decided **not** to
fix and your reasoning. A future reader needs to know what was considered, not
only what was changed.
