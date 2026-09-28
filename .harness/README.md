# Mise-Kal agent worktree harness

Isolated git worktrees for parallel sub-agents, so several can work at once
without ever touching each other's files.

This document is written so an agent that has never seen the repository can
operate the harness without guessing.

---

## 1. The problem this solves

A sub-agent that edits a shared checkout will, sooner or later, collide with
another sub-agent: two branches checked out at once, one agent's uncommitted
work swept into another's commit, or a test suite passing locally and failing
mysteriously because a sibling was rewriting the same file mid-run.

The harness removes the possibility rather than managing the symptom. Each agent
gets its own git worktree, its own branch, its own ports, its own scratch
directory. Nothing is shared except git's object store, which git already makes
safe for concurrent use.

**The rule:** if you find yourself adding a file that two agents write to, the
design is wrong. Put it in the agent's own scratch directory instead.

---

## 2. Layout

```
.harness/
├── README.md            ← you are here
├── harness.conf         ← machine-local tuning (git-ignored)
├── scripts/
│   ├── lib.sh           ← shared library; sourced, never executed
│   ├── worktree.sh      ← the command you will actually use
│   ├── test.sh          ← runs the suites with per-agent isolation
│   ├── wave.sh          ← wave lifecycle: open, status, integrate, close
│   ├── integrate.sh     ← controlled merge of an agent branch
│   ├── cleanup.sh       ← prune finished worktrees, locks, scratch
│   └── setup-tools.sh   ← fetch PocketBase and jq into cache/
├── tasks/               ← task definitions (committed)
├── waves/               ← wave manifests (committed)
├── worktrees/           ← the isolated trees themselves (git-ignored)
├── logs/                ← per-agent logs and scratch (git-ignored)
├── locks/               ← port reservations and locks (git-ignored)
└── cache/               ← downloaded tools (git-ignored)
```

Everything under `worktrees/`, `logs/`, `locks/`, `cache/` and `harness.conf` is
git-ignored. Only `tasks/`, `waves/`, `scripts/` and the docs are committed.

---

## 3. Quick start

```bash
# One-time: fetch PocketBase and jq into .harness/cache/
.harness/scripts/setup-tools.sh

# Check the machine can run anything at all
.harness/scripts/worktree.sh doctor

# Create your isolated worktree and reserve your ports
.harness/scripts/worktree.sh create --agent myname --task t-001-example

# Work inside it
cd .harness/worktrees/myname
# ... edit ...
.harness/scripts/test.sh --agent myname --all      # run from the repo root
git commit -am "feat(scope): what changed"

# Report and finish
.harness/scripts/worktree.sh report --agent myname --task t-001-example \
  --summary "What I did, what I verified, what is left."
.harness/scripts/worktree.sh remove --agent myname
```

An agent's whole life cycle:

```
inspect → plan → implement → test → commit → report
```

Never start editing before you have read the existing architecture. Never commit
without having run the suites. Never leave a worktree dirty at the end of a wave.

---

## 4. Commands

### `worktree.sh`

| Command | What it does |
|---|---|
| `create --agent NAME [--task ID] [--base REF]` | Makes the worktree, branch, port block and scratch. Idempotent — re-running reuses what exists. |
| `list` | Every worktree with branch, HEAD, clean/dirty, ahead/behind. |
| `status --agent NAME` | One agent in detail, including commits ahead of `origin/main`. |
| `claim --task ID --agent NAME` | Marks a task claimed. Refuses if another agent already holds it. |
| `run --task ID -- CMD...` | Runs a command inside the agent's worktree, logging to `logs/<agent>/<task>.log`. |
| `report --task ID --summary "..."` | Writes `logs/<agent>/report-<task>.md` with commits and a file diff. |
| `reset --agent NAME [--hard]` | Without `--hard` it changes nothing and shows you the state. With `--hard` it discards uncommitted work. |
| `remove --agent NAME [--force]` | Removes the worktree. Refuses if there are uncommitted changes unless `--force`. Keeps the branch. |
| `ports` | Who holds which port. |
| `doctor` | Checks the machine: git, worktree support, curl, unzip, PocketBase, jq, flutter. |

### `test.sh`

```bash
.harness/scripts/test.sh --agent NAME --all          # every backend suite + flutter
.harness/scripts/test.sh --agent NAME --suite smoke  # one suite
.harness/scripts/test.sh --agent NAME --app          # flutter test only
```

Add `--quiet` for summary-only output, `--keep` to keep the scratch note quiet.

### `wave.sh`

```bash
.harness/scripts/wave.sh open  wave-1 "Phase 1 stabilisation"
.harness/scripts/wave.sh add   wave-1 --agent alpha --task t-001
.harness/scripts/wave.sh status wave-1
.harness/scripts/wave.sh integrate wave-1        # merges finished agent branches
.harness/scripts/wave.sh close wave-1
```

### `cleanup.sh`

```bash
.harness/scripts/cleanup.sh --dry-run   # show what would go
.harness/scripts/cleanup.sh             # remove merged worktrees, stale locks, old scratch
```

---

## 5. The wave model

A **wave** is a batch of agents working in parallel on tasks that do not depend
on each other, followed by one controlled integration.

```
Wave 1   alpha: backend A     beta: docs B      gamma: tests C
             \                    |                   /
              +---- integrate into main ----------+
Wave 2   delta: reads Wave 1's result, builds on it
```

Rules:

1. Agents in a wave must not depend on each other's output. If B needs A's work,
   B belongs in the next wave.
2. Agents never commit to `main`. They commit to `agent/<name>/<task>`.
3. Integration happens once per wave, by the orchestrator, via `wave.sh integrate`.
4. A wave is not closed until every agent has reported and every branch is either
   merged or explicitly abandoned.
5. Wave 2 starts from the integrated `main`, so it sees Wave 1's result. This is
   what makes the model cumulative rather than a set of parallel universes.

---

## 6. Why the test suites are patched at run time

`.harness/scripts/test.sh` does not run upstream's suites directly. It generates
a patched copy of each one, outside the repository, and runs that. The originals
are never modified, so `git status` stays clean and upstream can be merged
freely.

Three things in the upstream suites break under concurrency. All three were
confirmed by reading the scripts, not assumed:

| Problem | What happens | Fix |
|---|---|---|
| Hardcoded ports 8091–8098 | Two agents on the same suite fight for a port; one gets a connection refused that looks like a product bug | Each agent gets a reserved block from `harness.conf` |
| Literal `/tmp/g.json`, `/tmp/p.json` | Git Bash does **not** honour `TMPDIR` for a literal `/tmp` path (verified by experiment), so agents overwrite each other's responses | Scratch paths are rewritten to the agent's own directory |
| `pkill -f "pocketbase serve --dir=./pb_test_data"` | `pkill -f` matches the command line as a string. Every agent's server has the *same* relative arguments, so agent A's cleanup kills agent B's server mid-suite | The server's PID is captured and only that process is killed |

The patcher **asserts on every substitution**. If upstream renames a variable or
restructures a suite, `test.sh` fails loudly with the missing marker rather than
silently running an unisolated suite. A silent failure here would be blamed on
the product code, which is exactly the confusion the harness exists to prevent.

---

## 7. Configuration

`harness.conf` is git-ignored and optional. Defaults work with no file at all.

```conf
# First port the harness may hand out.
PORT_BASE=8200
# How many ports each agent reserves.
PORT_BLOCK_SIZE=10
# How many distinct agent slots exist. Determines the hash space.
AGENT_SLOTS=16
```

---

## 8. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `Tools missing; fetching.` on every run | Cache was cleaned | Normal; it re-downloads once |
| `Timed out waiting for lock` | Another agent holds the lock, or a process died holding it | Wait, or remove `.harness/locks/<name>.lock` if you are sure nothing is running |
| `Worktree ... exists on branch ...` | You asked for a task name that does not match the existing worktree | Use the same `--task`, or `remove` it first |
| `Patch '<label>' failed` | Upstream changed a suite's structure | Update the pattern in `test.sh`; do not bypass the check |
| Port already in use | A previous run left a server alive | `.harness/scripts/cleanup.sh`, or check `worktree.sh ports` |
| `unbound variable` from a script | A `local a="$1" b="$a"` declaration | Split into separate `local` lines — bash expands all words before assigning |

---

## 9. Rules that keep this safe

- **Never commit to `main` from an agent worktree.** Commit to your own branch.
- **Never edit a sibling's worktree.** If you need their change, it has to be
  integrated into `main` first, then you rebase or merge from `main`.
- **Never put secrets in a task file, a wave manifest, or a commit message.**
  Tasks and waves are committed to a public repository.
- **Never `remove --force` another agent's worktree.** Uncommitted work is the
  most expensive thing in this repository.
- **Always leave the worktree clean** when your task is done: commit, or say in
  your report that you did not.
