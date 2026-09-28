---
id: t-000-template
title: Short imperative title
status: ready
owner: -
wave: -
priority: normal
depends_on: -
areas: []
---

# Objective

One paragraph. What is true after this task that is not true before it. Written
so that a reader who has never seen the repository understands the point of the
work, not just its mechanics.

# Why

The reason this is worth doing, and what breaks or stays painful without it.
If this is part of a phase, name the phase. If it fixes a known defect, describe
the defect and how it shows up for a user.

# Scope

**In scope**

- The specific thing being changed.

**Out of scope**

- The adjacent thing someone will be tempted to fix in the same pass, and why it
  is deliberately left alone. Naming it here is what keeps a task reviewable.

# Files and areas you may touch

```
server/pb_hooks/          allowed
server/pb_migrations/     allowed (new files only — never edit an applied one)
app/lib/features/pos/     allowed
app/lib/core/theme/       read-only
```

Anything not listed is out of bounds for this task. If the work genuinely
requires touching something else, say so in the report and let the orchestrator
decide — do not widen the scope silently.

# Dependencies

- `t-000-example` must be merged into `main` first, because ...

If there are none, write "None." Do not leave this blank; a blank dependency
field is indistinguishable from an unconsidered one.

# Acceptance criteria

Concrete and checkable. "Works correctly" is not a criterion.

- [ ] A specific observable behaviour.
- [ ] A specific edge case that must not regress.
- [ ] No change to any documented invariant (see `docs/developing.md`).

# Test requirement

Which suites must pass, and what new test covers the change.

```bash
.harness/scripts/test.sh --agent NAME --suite smoke
.harness/scripts/test.sh --agent NAME --app
```

If the change is to money math or order state, the `smoke` and `payments`
suites are mandatory. If it touches the guest routes, `guest` is mandatory. A
change with no test is not finished; if a test is genuinely impossible, the
report must say why.

# Commit requirement

- One commit per logical change, conventional-commit subject.
- Subject names the area: `feat(pos): ...`, `fix(kitchen): ...`, `docs: ...`.
- The body explains **why**, not what — the diff already shows what.
- Do not commit generated files, downloaded binaries, or scratch data.
- Never commit to `main`; commit to your own `agent/<name>/<task>` branch.

# Report requirement

```bash
.harness/scripts/worktree.sh report --agent NAME --task TASK-ID \
  --summary "What changed, what you verified, what is left or uncertain."
```

The report must state plainly anything you did not finish or could not verify.
An honest "not done" is far more useful than an optimistic "done".
