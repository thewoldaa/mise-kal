# Contributing to Mise-Kal

Mise-Kal is developed by parallel sub-agents working in isolated git worktrees.
This document is the contract that keeps that from becoming chaos.

If you are an agent reading this: follow it exactly. If you are a human: the
same rules apply, for the same reasons.

---

## 1. Before you touch anything

**Read the architecture first.** A change made without understanding the
existing design is how a codebase becomes something nobody can safely change.

Minimum reading, in order:

1. [`docs/developing.md`](docs/developing.md) — how it fits together, and the
   four rules the code leans on.
2. [`PLAN.md`](PLAN.md) — the design contract. **If the code and `PLAN.md`
   disagree, `PLAN.md` wins** until it is deliberately updated.
3. [`.harness/README.md`](.harness/README.md) — the harness you will work in.
4. The task file you are about to work on, in full.

The four rules from `developing.md`, which you must not break:

- **Money is only ever computed on the server.** The app displays totals; it
  never adds them up.
- **Menu names and prices are snapshotted onto order lines.** Editing tomorrow's
  menu must never rewrite yesterday's bill.
- **Takings are counted by when a bill closed**, not when it opened.
- **Ageing and status use separate colour channels** on the kitchen display.

## 2. Your workflow

Every task follows the same six steps. Do not skip one because the change looks
small.

```
inspect → plan → implement → test → commit → report
```

```bash
# 1. Inspect and plan — read the task, read the code it touches.
#    Say out loud what you are going to change and why. If you cannot, you do
#    not understand it well enough yet.

# 2. Create your isolated worktree
.harness/scripts/worktree.sh create --agent <yourname> --task <task-id>

# 3. Claim the task so nobody else takes it
.harness/scripts/worktree.sh claim --agent <yourname> --task <task-id>

# 4. Work inside your worktree
cd .harness/worktrees/<yourname>

# 5. Test — mandatory, and before the commit, not after
.harness/scripts/test.sh --agent <yourname> --all

# 6. Commit on your own branch
git commit -m "feat(scope): what changed"

# 7. Report
.harness/scripts/worktree.sh report --agent <yourname> --task <task-id> \
  --summary "What changed, what you verified, what is left."
```

## 3. Branch rules

| Rule | Why |
|---|---|
| **Never commit to `main`.** | `main` is the integration point. An agent committing directly to it bypasses review and can break every other agent's base. |
| Your branch is `agent/<name>/<task>`. | Created for you by `worktree.sh`. It names who and what, which is what makes a merge attributable. |
| One task per branch. | Two tasks on one branch cannot be reviewed or reverted separately. |
| Rebase or merge from `main` when it moves. | Do it in your own worktree, so the conflict is yours to resolve and never lands on `main`. |

## 4. Commit rules

- **Conventional commits**, with the area in the scope:
  `feat(pos):`, `fix(kitchen):`, `docs:`, `test(harness):`, `ci:`, `refactor:`.
- **The subject is imperative and specific.** `fix(pos): keep the table
  occupied until the bill is settled` — not `fixed bug`.
- **The body explains why, not what.** The diff already shows what changed.
  A body that restates the diff is noise; a body that says "without this, a
  table seated before a shift change is credited to the wrong shift" is worth
  having.
- **One logical change per commit.** If the message needs an "and", it is
  probably two commits.
- **Never commit:** generated files, downloaded binaries, scratch data, `.env`,
  credentials, or anything from `.harness/cache/` or `.harness/logs/`.

`.harness/scripts/security-check.sh` runs on every push in CI and fails if any
of that gets tracked. Run it yourself before pushing.

## 5. Test rules

A change without a test is not finished.

| You changed | Minimum |
|---|---|
| Money math, order state, or anything in `pb_hooks/lib_money.js` | `smoke` and `payments` |
| The guest routes | `guest` |
| Staff roles or guards | `staff` |
| Kitchen state | `kitchen` |
| Flutter code | `flutter test`, plus a test for the new behaviour |
| Schema | `smoke` and `payments`, plus a new migration |

- **Never edit an applied migration.** Add a new one. An edited migration
  produces a different schema on a machine that already ran it, which is a
  data-corruption class of bug.
- **Never weaken a test to make it pass.** If a test is wrong, fix it and say so
  in the commit body. If it is right, your change is wrong.
- **A flaky test is a bug.** Report it rather than re-running until it passes.

## 6. The wave model

Work is organised into waves. A wave is a set of agents working in parallel on
tasks that do not depend on each other, followed by one controlled integration.

```
Wave 1   alpha: task A     beta: task B     gamma: task C
              \                |                 /
               +---- integrate into main ------+
Wave 2   delta: reads Wave 1's result
```

```bash
.harness/scripts/wave.sh open  wave-1 "Phase 1 stabilisation"
.harness/scripts/wave.sh add   wave-1 --agent alpha --task t-001-windows-paths
.harness/scripts/wave.sh status wave-1
.harness/scripts/wave.sh integrate wave-1 --dry-run   # conflict check
.harness/scripts/wave.sh integrate wave-1             # real merge + suites
.harness/scripts/wave.sh close wave-1
```

Rules:

- Agents in one wave must not depend on each other. If B needs A's output, B
  belongs in the next wave.
- Integration is done by the orchestrator, once per wave, and only after every
  agent has committed and reported.
- Integration runs the full suite on the merged result. Green on a branch is not
  green on `main`; only the merged run proves it.

## 7. Security rules

**This repository is public.** Read [SECURITY.md](SECURITY.md) before you commit
anything that feels personal.

- **Never commit a secret.** No API keys, tokens, passwords, private keys or
  connection strings — not even a fake-looking one that happens to be real.
- **Never commit personal agent material.** Private prompts, memory files,
  personal notes and local agent configuration are git-ignored on purpose. Do
  not add them back with `git add -f`.
- **Never commit a real credential into a test fixture.** Use obvious fakes like
  `test-key-not-real`.
- **Configuration goes in a template.** If a new setting is needed, add it to
  `.env.example` with an empty value and document it. The real value goes in
  `.env`, which is never committed.
- **If you commit a secret by accident**, say so immediately. Rotating the
  credential is the fix; deleting the commit is not, because the value is
  already in history and may already have been fetched.

## 8. What not to do

- **Do not delete a working upstream feature to make an implementation
  simpler.** Changes must be incremental and backward-aware. If a feature is
  genuinely wrong, that is a task with a rationale, not a quiet removal.
- **Do not widen a task's scope silently.** If the work genuinely requires
  touching files outside your task's allowed areas, say so in the report and let
  the orchestrator decide.
- **Do not rewrite the schema in place.** Migrations only.
- **Do not reformat files you are not changing.** It buries the real diff.
- **Do not leave your worktree dirty.** Commit, or say in your report that you
  did not and why.

## 9. Getting help

- The harness is misbehaving: `.harness/scripts/worktree.sh doctor`
- A suite is failing: `.harness/scripts/test.sh --agent <you> --suite <name>`,
  then read `.harness/logs/<you>/<suite>.log`
- Unsure whether something is private: `.harness/scripts/security-check.sh --all`
- The task is ambiguous: **stop and ask.** A wrong assumption implemented
  confidently costs far more than a question.
