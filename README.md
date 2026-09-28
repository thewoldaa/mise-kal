# Mise-Kal

A free, self-hosted restaurant management system — POS, kitchen display, menu
management and sales reports, running on the restaurant's own hardware.

**Mise-Kal is a derivative of [Mise](https://github.com/devShakib015/mise)**,
forked and developed independently as a long-term project. It keeps everything
that makes Mise good — the offline-first design, the server-side money rules,
the bundled-server installer — and aims it at a modular, testable, maintainable
architecture for continued development.

Free forever. No licence key, no account, no subscription, no telemetry, no
paid tier. The restaurant's data lives on the restaurant's machine.

Because the server runs on-site, **the POS keeps taking orders when the internet
goes down** — which for a restaurant matters more than almost anything else.

---

## Relationship to upstream

| | |
|---|---|
| **Upstream** | [devShakib015/mise](https://github.com/devShakib015/mise) |
| **Upstream licence** | MIT, © 2026 K M Shahriar Hossain |
| **This repository** | a standalone project, not a GitHub fork |
| **Forked at** | upstream `main` @ `c56d1c3` |

Mise-Kal is the source of truth for its own development. Upstream is kept as a
git remote so improvements can be pulled in deliberately:

```bash
git fetch upstream
git log --oneline main..upstream/main     # what upstream has that we do not
git merge upstream/main                    # when it is worth taking
```

The upstream copyright notice is preserved in [LICENSE](LICENSE), as the MIT
licence requires. Mise-Kal's own changes are additionally recorded there.

### What Mise-Kal changes

**1. An isolated multi-agent worktree harness (`.harness/`).**
The largest addition. Several sub-agents work in parallel, each in its own git
worktree, with its own branch, its own reserved port block and its own scratch
directory — so two agents can never touch each other's files. Work is integrated
in controlled waves rather than by merging by hand. See
[`.harness/README.md`](.harness/README.md).

**2. The test suites now run on Windows.**
Upstream's suites were written for a single developer on macOS. Three things in
them break under concurrency, and one breaks on Windows at all:

- hardcoded ports 8091–8098;
- shared scratch files in a literal `/tmp` (Git Bash does not honour `TMPDIR`
  for a literal path, so these genuinely collide);
- `pkill -f "pocketbase serve --dir=./pb_test_data"`, which matches by command
  line and therefore kills a sibling agent's server mid-suite.

The harness patches a copy of each suite at run time — with an absolute server
path, a per-agent port, a per-agent data directory and PID-based cleanup —
instead of editing the originals, so upstream stays mergeable. All 101 backend
checks and 54 Dart tests pass on Windows.

**3. `.gitattributes`.**
On Windows, git's default `core.autocrlf=true` rewrites every `.sh` file to
CRLF, and bash then fails on `set -euo pipefail` before running a single line.
Line endings are now pinned in the repository rather than left to each
developer's git config.

**4. Public/private separation.**
The repository carries project instructions and templates. Personal agent
instructions, memory, credentials and machine-specific configuration are
git-ignored, with a script that fails the build if any of them are ever tracked.
See [SECURITY.md](SECURITY.md).

**5. Development roadmap.**
Upstream's plan stops at packaging. Mise-Kal continues with Indonesian
localization, QRIS payments, WhatsApp notifications, inventory, multi-branch,
an owner dashboard, backup/sync and analytics — in that order, one wave at a
time. See the task index at [`.harness/tasks/`](.harness/tasks/).

---

## Stack

| Layer | Choice |
|---|---|
| Backend | [PocketBase](https://pocketbase.io) — one binary: database, auth, realtime, file storage |
| Apps | Flutter — one binary, three role-based shells (POS / KDS / Manager) |
| Printing | ESC/POS over TCP 9100, with PDF fallback |

## Running it locally

```bash
./server/scripts/dev.sh
```

First run downloads the pinned PocketBase version into `server/bin/` and applies
the schema migrations. The admin UI is then at <http://127.0.0.1:8090/_/>.

Then, in a second terminal:

```bash
cd app && flutter run -d windows
```

`-d macos`, `-d linux` and `-d chrome` work too. On first launch, point the app
at `127.0.0.1:8090`.

## Tests

Seven suites. Each backend suite spins up a throwaway database on its own port
and tears it down afterwards; none of them touch your real data.

```bash
# Everything, with per-agent isolation
.harness/scripts/test.sh --agent local --all

# One backend suite
.harness/scripts/test.sh --agent local --suite smoke

# Dart tests only
.harness/scripts/test.sh --agent local --app
```

Or the suites directly, one at a time:

```bash
for s in smoke setup kitchen payments staff guest; do ./server/scripts/${s}_test.sh; done
cd app && flutter test
```

- `smoke` — order numbering, modifier pricing, tax and service charge, voids,
  table release, and that a forged total is overwritten
- `setup` — the first-run endpoints, and that bootstrap can never run twice
- `kitchen` — a bill's status following its lines, and the guards that stop it
  touching bills which are not in service
- `payments` — part payments, settlement, discounts, and refusing money against
  a cancelled bill
- `staff` — resetting a forgotten PIN, and the guards that stop a manager
  seizing an owner's account or the venue losing its last owner
- `guest` — table-side ordering: that a guest sees only the menu, that no price
  comes from the request, and that a stranger cannot put food on the pass

## Installing it

macOS installs from a DMG; see [docs/install-macos.md](docs/install-macos.md).
A Windows installer is planned — see
[`.harness/tasks/t-030-windows-installer.md`](.harness/tasks/t-030-windows-installer.md).

## Working on Mise-Kal

Start with [CONTRIBUTING.md](CONTRIBUTING.md). The short version:

```bash
.harness/scripts/setup-tools.sh                     # PocketBase + jq into cache
.harness/scripts/worktree.sh create --agent myname  # isolated worktree
cd .harness/worktrees/myname
# ... work ...
.harness/scripts/test.sh --agent myname --all
git commit -m "feat(scope): ..."
```

Architecture, the four rules the code leans on, and the things that will bite
you are in [docs/developing.md](docs/developing.md).

## How it is put together

`server/pb_migrations/` is the schema, in version control, so a fresh install is
reproducible. `server/pb_hooks/` holds the rules that cannot live on the client:
order numbering and **all money math**. A point-of-sale system must never let a
client tell the server what a bill costs, so every total is recomputed
server-side on write and a forged total is simply overwritten.

Menu names and prices are snapshotted onto each order line. Editing tomorrow's
menu must never rewrite yesterday's bill.

Two rules the whole system leans on. **Money is only ever computed on the
server** — the app displays totals, it never adds them up. And **takings are
counted by when a bill closed**, not when it was opened, so a table seated
before a shift began and settled during it belongs to that shift.

Receipts print over TCP 9100 from the desktop and tablet builds. A browser
cannot open a raw socket, so the web build says so rather than failing quietly.

## Licence

MIT. Use it, change it, run it in your restaurant, sell services around it —
just keep the copyright notice. See [LICENSE](LICENSE).

Upstream copyright © 2026 K M Shahriar Hossain, preserved as the licence
requires.
