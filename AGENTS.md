# AGENTS.md — working in Mise-Kal

This file is for any AI agent working in this repository. It is **public and
project-facing**: it documents how to work here, not who is working here.

> **Keep private material out.** Personal prompts, individual memory files,
> local agent configuration and credentials do not belong in this repository.
> They are git-ignored on purpose. If you need them, they live on the
> developer's machine, not here. See [SECURITY.md](SECURITY.md).

---

## Read this first

Before changing anything, read:

1. [`PLAN.md`](PLAN.md) — the design contract. **If code and `PLAN.md` disagree,
   `PLAN.md` wins** until it is deliberately updated.
2. [`docs/developing.md`](docs/developing.md) — architecture and the four rules.
3. [`CONTRIBUTING.md`](CONTRIBUTING.md) — the workflow contract.
4. [`.harness/README.md`](.harness/README.md) — the worktree harness.
5. The task file you are working on, **in full**.

## The one-paragraph version

Work in an isolated git worktree, on your own branch, never on `main`. Inspect
and plan before implementing. Run the test suites before committing. Commit in
conventional-commit form, explaining why. Write a report that says plainly what
you did not finish. Do not commit secrets. Do not delete working upstream
features to make something simpler.

## Setup

```bash
.harness/scripts/setup-tools.sh          # PocketBase + jq into .harness/cache/
.harness/scripts/worktree.sh doctor      # verify the machine can run anything
```

## Your loop

```bash
.harness/scripts/worktree.sh create --agent <you> --task <task-id>
.harness/scripts/worktree.sh claim  --agent <you> --task <task-id>
cd .harness/worktrees/<you>
# ... inspect, plan, implement ...
.harness/scripts/test.sh --agent <you> --all
git commit -m "feat(scope): why this change"
.harness/scripts/worktree.sh report --agent <you> --task <task-id> --summary "..."
```

## Hard rules

**Never break these. They are not style preferences.**

| Rule | Why it exists |
|---|---|
| **Never commit to `main`.** | `main` is the integration point; other agents branch from it. |
| **Money is only ever computed server-side.** | A POS must never let a client decide what a bill costs. |
| **Never edit an applied migration.** Add a new one. | An edited migration produces a different schema on a machine that already ran it. |
| **Never weaken a test to make it pass.** | If the test is right, your change is wrong. |
| **Never commit a secret.** | The repository is public and history is forever. |
| **Never touch a sibling agent's worktree.** | Their uncommitted work is unrecoverable if you do. |
| **Never delete a working upstream feature** to simplify an implementation. | Changes must be incremental and backward-aware. |
| **Never widen your task's scope silently.** | Report it instead; the orchestrator decides. |

## Test requirements by area

| Changed | Run at minimum |
|---|---|
| Money, order state, `lib_money.js` | `--suite smoke` and `--suite payments` |
| Guest routes | `--suite guest` |
| Staff roles or guards | `--suite staff` |
| Kitchen state | `--suite kitchen` |
| Flutter code | `--app` |
| Anything | `--all` |

## Things that will bite you

From `docs/developing.md`, plus what the harness learned:

- **PocketBase hooks run in their own runtime.** A function declared at the top
  of a `.pb.js` is not defined inside the handler. Put shared code in `lib_*.js`
  and `require` it *inside* each handler.
- **PocketBase zero values are truthy objects.** An empty date is a zero
  `DateTime`, so `!record.get("closed_at")` never fires. Use `getString()` and
  compare to `""`. A `json` field is a byte array that passes `Array.isArray` —
  decode with `.string()` first.
- **Filters bind client-side.** `pb.filter("x = {:v}", {...})`, not a `query`
  map.
- **On Windows, bash scripts need LF.** `.gitattributes` pins this. A stray
  `\r` makes bash look for a command named `pipefail\r`.
- **In bash, `local a="$1" b="$a"` does not work.** All words expand before any
  assignment, so `$a` is unset. Use separate `local` lines. Under `set -u` the
  failure is an "unbound variable" abort.
- **`pkill -f` matches command lines as strings.** Two agents running the same
  suite have identical command lines, so one agent's cleanup kills the other's
  server. Kill by PID.
- **Git Bash does not honour `TMPDIR` for a literal `/tmp` path.** Shared
  scratch files genuinely collide.

## If something is wrong with the harness

`.harness/scripts/worktree.sh doctor` first. Then read the relevant script —
they are commented with the reasoning, not just the mechanics. If a suite fails,
the log is at `.harness/logs/<agent>/<suite>.log`.

Do not work around a harness bug by editing upstream's test scripts in place.
The harness patches a copy at run time precisely so upstream stays mergeable.
Fix the harness, or report it.
