# Task index

Every task is a markdown file in this directory with front matter. The front
matter is what the harness reads; the body is what a human or agent reads.

## Status values

| Status | Meaning |
|---|---|
| `draft` | Written down, not ready to start. Usually needs a decision first. |
| `ready` | Fully specified. An agent can pick it up and work without asking. |
| `claimed` | An agent owns it. Set by `worktree.sh claim`, not by hand. |
| `done` | Merged into `main` and verified. |
| `blocked` | Cannot proceed; the blocker is named in the body. |

## Fields

```yaml
id:          kebab-case, matches the filename without .md
title:       short imperative sentence
status:      draft | ready | claimed | done | blocked
owner:       agent name, or - when unclaimed
wave:        which wave it belongs to, or - if unassigned
priority:    high | normal | low
depends_on:  task id, or - if none
areas:       which parts of the repo it touches
```

## Rules

- **A task must be `ready` before an agent starts it.** A `draft` task is a
  placeholder for a decision that has not been made.
- **`depends_on` is a hard ordering.** If B depends on A, B goes in a later wave.
  This is the mechanism that makes the wave model work; ignoring it produces two
  agents editing the same file from different assumptions.
- **`areas` must match the "Files and areas you may touch" section** in the body.
  If they disagree, the body is right and the front matter is a bug.
- **One task, one reviewable change.** If the acceptance criteria cannot be
  checked in a single sitting, the task is too big — split it.
- **Never put a secret in a task.** These files are committed to a public
  repository. Credentials go in `.env`, which is git-ignored.

## Current tasks

### Wave 1 — stabilisation

| ID | Title | Status | Depends on |
|---|---|---|---|
| `t-001-windows-paths` | Audit Windows path and shell portability | ready | — |
| `t-002-ci-pipeline` | CI pipeline running both suites | ready | — |

### Wave 2 — installer and localization

| ID | Title | Status | Depends on |
|---|---|---|---|
| `t-010-id-locale` | Indonesian locale support | ready | t-001 |
| `t-030-windows-installer` | Windows installer | ready | t-001 |

### Wave 3 — payments

| ID | Title | Status | Depends on |
|---|---|---|---|
| `t-020-qris-layer` | QRIS payment integration layer | draft | t-010 |

### Not yet written

The roadmap below is the intended order. A task is written when the wave before
it is close to finishing, so that later tasks can be specified against what
actually exists rather than against a guess.

| Phase | Area | Notes |
|---|---|---|
| 4 | WhatsApp / business notifications | Needs the payment layer's outbound pattern |
| 5 | Inventory and stock | Schema change; needs migrations discipline |
| 6 | Multi-branch | The largest architectural change; needs a design task first |
| 7 | Owner dashboard | Depends on multi-branch for anything cross-venue |
| 8 | Backup and sync | Depends on multi-branch |
| 9 | Analytics / AI-assisted insights | Depends on reporting data being trustworthy |
| 10 | Production hardening | Ongoing, not a single task |
