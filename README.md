<div align="center">

# Mise-Kal

**A self-hosted restaurant management system.**

Point of sale, kitchen display, and back-office management in one application,
running on the restaurant's own hardware. No cloud account, no subscription, no
telemetry.

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Release](https://img.shields.io/github/v/release/thewoldaa/mise-kal?label=release&color=blue)](https://github.com/thewoldaa/mise-kal/releases)
[![Tests](https://img.shields.io/badge/tests-175%20passing-brightgreen.svg)](#testing)
[![Flutter](https://img.shields.io/badge/Flutter-3.47.5-02569B.svg)](https://flutter.dev)
[![PocketBase](https://img.shields.io/badge/PocketBase-0.40.1-000000.svg)](https://pocketbase.io)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux%20%7C%20Android%20%7C%20iOS-lightgrey.svg)](#installation)
[![Status](https://img.shields.io/badge/status-pre--1.0-orange.svg)](#roadmap)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

**[Documentation](https://thewoldaa.github.io/mise-kal/docs/)** &nbsp;&middot;&nbsp;
**[Interactive demo](https://thewoldaa.github.io/mise-kal/demo/)** &nbsp;&middot;&nbsp;
**[Website](https://thewoldaa.github.io/mise-kal/)**

</div>

---

Because the server runs on-site, the POS continues to take orders when the
internet goes down. For a restaurant, that matters more than almost any other
property of the system.

Mise-Kal is a **fork of [Mise](https://github.com/devShakib015/mise)** by
**K M Shahriar Hossain**, developed independently as a long-term project.

| | |
|---|---|
| **Upstream** | [devShakib015/mise](https://github.com/devShakib015/mise) |
| **Forked at** | upstream `main` @ `c56d1c3` |
| **License** | MIT, upstream copyright preserved |
| **Platform** | Windows, macOS, Linux, Android, iOS |
| **Backend** | PocketBase 0.40.1 (single binary) |
| **Application** | Flutter 3.47.5 |
| **Tests** | 101 backend checks, 76 Dart tests |
| **Status** | Pre-1.0, active development |

---

## Table of contents

- [Capabilities](#capabilities)
- [Design invariants](#design-invariants)
- [Architecture](#architecture)
- [Installation](#installation)
- [Development](#development)
- [Testing](#testing)
- [Repository layout](#repository-layout)
- [Roadmap](#roadmap)
- [Contributing](#contributing)
- [Security](#security)
- [Acknowledgements](#acknowledgements)

---

## Capabilities

### Point of sale

Floor plan with live bill totals per table. Order taking with modifiers,
kitchen notes, and quantities. Send-to-kitchen in one action. Partial payments
accumulating to settlement. Discounts by percentage or amount, each with a
reason and each written to the audit log. Voids are recorded rather than
silently deleted.

The till keeps working when the network drops: adding to a bill is queued to
disk and drains automatically when the server answers again.

### Kitchen display

Tickets appear the moment the till fires them, sized to read from across a
kitchen. Tapping an item walks it through queued, cooking, ready. Timers count
from when the ticket was fired and the card ages neutral to amber to red against
a ten-minute target. A bill's status is derived server-side so every terminal
agrees on it.

### Management

Menu with categories, photographs, tags, preparation times, modifier groups, and
a sold-out toggle. Tables grouped into zones. Staff accounts with five roles,
each described in plain language rather than by permission flags; a manager can
reset a forgotten PIN without anyone opening the admin dashboard. Sales broken
down by item, by who served it, and by hour, with CSV export.

### Table-side ordering

A guest scans the QR code on their table and orders from their own phone. It is
a web page, not an application to install. It runs on the same server and port,
so nothing is exposed to the internet and there is no second process to manage.

Guests reach exactly three public routes; all fourteen collections remain
staff-only. No price is ever taken from the request. Their items land on the
table's bill unsent, and a waiter fires them.

### Hardware

Network thermal printers over TCP 9100 using ESC/POS, which is what virtually
every restaurant printer already speaks, with no driver to install. A printer is
an address and a paper width. Receipts and kitchen tickets, with a PDF fallback.

---

## Design invariants

These are not style preferences. Each is enforced in code and covered by a test.
Breaking one silently is how a restaurant loses money.

### Money is only ever computed on the server

`server/pb_hooks/lib_money.js` recomputes every order's totals on write. A client
that PATCHes a forged total has it overwritten.

A point-of-sale system must never let a client decide what a bill costs. The
tablet is on the restaurant's wi-fi and could be anything.

*Test:* `smoke`, "Client cannot forge a total".

### Menu names and prices are snapshotted onto order lines

When an item is added to an order, its name and unit price are copied onto the
line. The line does not reference the menu item for pricing.

Editing tomorrow's menu must never rewrite yesterday's bill.

### Takings are counted by when a bill closed

Reports and shifts key on `closed_at`, not `created_at`.

A table seated before a shift began and settled during it is that shift's
takings. Keying on creation credits the money to the wrong session and leaves
the drawer looking short.

### Ageing and status use separate visual channels

On the kitchen display, a ticket's border and timer carry how long it has been
waiting. Its dots and chips carry what state each item is in.

Merging them makes a late ticket full of cooking items unreadable: the two
meanings fight each other. A red frame with blue dots reads correctly at a
glance.

---

## Architecture

```
+-------------------------------------------------------------------------+
|                          RESTAURANT LAN                                 |
|                                                                         |
|   +-------------------+                    +------------------------+   |
|   |  Flutter app      |                    |  Guest phone           |   |
|   |                   |                    |                        |   |
|   |  POS shell        |                    |  QR code -> web page   |   |
|   |  KDS shell        |                    |  3 public routes only  |   |
|   |  Manager shell    |                    |  no price from request |   |
|   +---------+---------+                    +-----------+------------+   |
|             |                                          |                |
|             |  HTTP (LAN only)                         |                |
|             +------------------+   +-------------------+                |
|                                |   |                                    |
|                                v   v                                    |
|              +---------------------------------------------+            |
|              |  PocketBase (single binary, on-site)        |            |
|              |                                             |            |
|              |  +----------------+  +-------------------+  |            |
|              |  |  Migrations    |  |  Hooks            |  |            |
|              |  |                |  |                   |  |            |
|              |  |  the schema    |  |  order numbering  |  |            |
|              |  |  version       |  |  ALL MONEY MATH   |  |            |
|              |  |  controlled    |  |  role guards      |  |            |
|              |  |                |  |  audit log        |  |            |
|              |  +----------------+  +-------------------+  |            |
|              |                                             |            |
|              |  +----------------+  +-------------------+  |            |
|              |  |  SQLite        |  |  Realtime subs    |  |            |
|              |  +----------------+  +-------------------+  |            |
|              +---------------------------------------------+            |
|                                                                         |
|   +-------------------+                                                 |
|   |  Thermal printer  |<-------- ESC/POS over TCP 9100 -----------------+|
|   |  receipt / pass   |                                                 |
|   +-------------------+                                                 |
+-------------------------------------------------------------------------+
```

### Request path for one order

```
  Waiter taps a menu item
          |
          v
  +-----------------+     optimistic local line
  |  POS shell      |---------------------------->  shown immediately
  +--------+--------+
           |
           |  create order_items record
           v
  +-----------------+     recompute line total,
  |  lib_money.js   |     then recompute the bill,
  |  (server hook)  |     then persist
  +--------+--------+
           |
           |  after-success hook
           v
  +-----------------+     realtime subscription
  |  KDS shell      |<----------------------------  ticket appears
  +-----------------+                                no refresh, no polling
```

### Offline behaviour

```
  Network up        Network down              Network restored
  ----------        ------------              ----------------
  write sent   -->  write queued to disk  --> queue drains,
  to server         (addLine only)            oldest first,
                                             stops at first failure
                                             so ordering survives
```

Opening a bill and settling one deliberately do **not** work offline. Opening a
bill needs a number the server assigns, and settling one needs a total only the
server computes. Settling against a made-up number is how a restaurant loses
money.

---

## Installation

### Requirements

| Component | Version | Notes |
|---|---|---|
| Flutter | 3.47 or later | For running from source or building |
| Git Bash | Any recent | Windows only; every script is POSIX shell |
| Developer Mode | Enabled | Windows build only; Flutter needs symlinks for plugins |

PocketBase is downloaded on demand. There is no database to install and no cloud
account to create.

### Running from source

```bash
git clone https://github.com/thewoldaa/mise-kal.git
cd mise-kal

# Terminal 1 - the server
./server/scripts/dev.sh

# Terminal 2 - the application
cd app && flutter run -d windows
```

The first run fetches the pinned PocketBase into `server/bin/` and applies the
schema migrations. The admin interface is then at `http://127.0.0.1:8090/_/`.

On first launch, point the application at `127.0.0.1:8090`. The `-d macos`,
`-d linux` and `-d chrome` targets work as well.

### Building for Windows

```bash
installer/windows/build_windows.sh
```

Produces a runnable build at `app/build/windows/x64/runner/Release/Mise.exe`
with PocketBase staged into it, so the application starts its own server on
first run.

Developer Mode must be enabled once, as an administrator:

```
start ms-settings:developers
```

The script checks for this before doing anything and explains the fix rather
than failing with Flutter's message, which does not name the prerequisite.

### Building for macOS

```bash
./installer/macos/build_dmg.sh
```

Produces a DMG. It is unsigned unless `CODESIGN_IDENTITY` is set; users open it
from the right-click menu once. See [docs/install-macos.md](docs/install-macos.md).

---

## Development

### Setup

```bash
# One-time: fetch PocketBase and jq into the harness cache
.harness/scripts/setup-tools.sh

# Verify the machine can run everything
.harness/scripts/worktree.sh doctor
```

### Working in an isolated worktree

```bash
.harness/scripts/worktree.sh create --agent <name> --task <task-id>
cd .harness/worktrees/<name>
# ... inspect, plan, implement, test ...
.harness/scripts/test.sh --agent <name> --all
git commit -m "feat(scope): what changed and why"
.harness/scripts/worktree.sh report --agent <name> --task <task-id> --summary "..."
```

Each agent receives its own git worktree, branch, reserved port block, and
scratch directory. Nothing is shared except git's object store, which git
already makes safe for concurrent use.

### The wave model

```
  Wave 1    agent A: task 1     agent B: task 2     agent C: task 3
                  \                   |                   /
                   +------ integrate into main ----------+
  Wave 2    agent D: reads the result of Wave 1, builds on it
```

Integration refuses to start from a dirty `main`, runs a trial merge to detect
conflicts before anything lands, merges each branch as its own attributable
commit, runs the full suite on the merged result, and verifies that each branch
is genuinely an ancestor of `main` afterwards.

```bash
.harness/scripts/wave.sh open wave-1 "Phase 1 stabilisation"
.harness/scripts/wave.sh add  wave-1 --agent alice --task t-001
.harness/scripts/wave.sh integrate wave-1 --dry-run   # conflict check only
.harness/scripts/wave.sh integrate wave-1             # merge and verify
.harness/scripts/wave.sh close wave-1
```

See [`.harness/README.md`](.harness/README.md) for the full manual.

---

## Testing

```bash
.harness/scripts/test.sh --agent <name> --all          # everything
.harness/scripts/test.sh --agent <name> --suite smoke  # one backend suite
.harness/scripts/test.sh --agent <name> --app          # Dart tests only
```

### Backend suites

Each spins up a throwaway database on its own port and tears it down afterwards.
None of them touch real data.

| Suite | Covers |
|---|---|
| `smoke` | Order numbering, modifier pricing, tax and service charge, voids, table release, forged totals |
| `setup` | First-run endpoints, and that bootstrap can never run twice |
| `kitchen` | A bill's status following its lines, and the guards on bills not in service |
| `payments` | Part payments, settlement, discounts, refusing money against a cancelled bill |
| `staff` | PIN resets, privilege guards, and that a venue cannot lose its last owner |
| `guest` | Table-side ordering: menu visibility, server-side pricing, route isolation |

### Dart tests

Printing, reporting, the offline queue, and localization. The offline queue
tests use a fake PocketBase speaking HTTP on a loopback socket rather than a
mock object, because what matters is that a real `ClientException` with
`statusCode == 0` comes back out of the SDK. That distinction is what
`isNetworkFailure` keys on to decide between keeping a write for retry and
dropping it as refused.

### Why the harness patches the suites

Upstream's suites were written for a single developer on one machine. Three
things in them break under concurrency, and all three were confirmed by reading
the scripts:

| Problem | What happens | Fix |
|---|---|---|
| Hardcoded ports 8091-8098 | Two agents on the same suite fight over a port; one gets a connection refused that looks like a product bug | Each agent gets a reserved block |
| Literal `/tmp/g.json` | Git Bash does not honour `TMPDIR` for a literal `/tmp` path, so agents overwrite each other's responses | Scratch paths are rewritten per agent |
| `pkill -f "pocketbase serve --dir=..."` | `pkill -f` matches command lines as strings; every agent's server has identical relative arguments, so one agent's cleanup kills another's server mid-suite | The server's PID is captured and only that process is killed |

The harness generates a patched copy at run time and leaves the originals
untouched, so upstream stays mergeable. It asserts on every substitution, so an
upstream restructure fails loudly rather than silently running an unisolated
suite.

---

## Repository layout

```
mise-kal/
├── PLAN.md                  Design contract inherited from upstream
├── README.md                This file
├── CONTRIBUTING.md          Workflow contract
├── SECURITY.md              Threat model and the guarantees the code keeps
├── AGENTS.md                How an AI agent works in this repository
├── LICENSE                  MIT, with the upstream copyright preserved
├── .env.example             Configuration template, no values
│
├── .harness/                Multi-agent development harness
│   ├── README.md            Operating manual
│   ├── scripts/             worktree, wave, test, integrate, cleanup, security
│   ├── tasks/               Task definitions with front matter
│   └── waves/               Wave manifests
│
├── server/                  PocketBase: schema and all business rules
│   ├── VERSION              Pinned PocketBase version
│   ├── pb_migrations/       The schema, version-controlled
│   ├── pb_hooks/            Rules that cannot live on a client
│   ├── pb_public/           The guest-facing page
│   ├── scripts/             Dev server and six test suites
│   └── fetch_pocketbase.sh  Downloads the pinned binary
│
├── app/                     Flutter: one binary, three role-based shells
│   ├── lib/core/            Design system, discovery, printing, reporting
│   ├── lib/data/            Models, repositories, offline queue
│   ├── lib/features/        setup, auth, pos, kds, manager
│   ├── lib/l10n/            Indonesian and English translations
│   └── test/                Dart tests
│
├── installer/               Packaging, per platform
└── docs/                    Owner guide, developer guide, architecture
```

---

## Roadmap

| Phase | Focus | Status |
|---|---|---|
| 1 | Stabilise the implementation, tests, and installer | In progress |
| 2 | Indonesian localization | In progress |
| 3 | Payment and QRIS integration layer | Planned |
| 4 | WhatsApp and business notifications | Planned |
| 5 | Inventory and stock control | Planned |
| 6 | Multi-branch support | Planned |
| 7 | Owner dashboard | Planned |
| 8 | Backup and sync architecture | Planned |
| 9 | Analytics and AI-assisted business insights | Planned |
| 10 | Production hardening | Planned |

Task definitions with acceptance criteria live in
[`.harness/tasks/`](.harness/tasks/).

---

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md) first. The short version:

```
inspect -> plan -> implement -> test -> commit -> report
```

- Never commit to `main`; work on `agent/<name>/<task>`
- Run the suites before committing
- Use conventional commits, and explain why rather than what
- Never delete a working upstream feature to simplify an implementation
- Never commit credentials; this repository is public

---

## Security

The threat model, the guarantees the code is built to keep, and the test that
proves each one are in [SECURITY.md](SECURITY.md).

Report a vulnerability through a
[private security advisory](https://github.com/thewoldaa/mise-kal/security/advisories/new),
not a public issue.

---

## Acknowledgements

Mise-Kal is a fork of [Mise](https://github.com/devShakib015/mise) by
**K M Shahriar Hossain**, which established the security posture and design
decisions this project inherits, in particular the rule that money is only ever
computed server-side.

Upstream is not a distant ancestor: it is the foundation. The PocketBase schema
and hooks, the Flutter application structure, the design system, and the test
suites all began there. What Mise-Kal adds is the development harness, Windows
support, Indonesian localization, and the site — see
[the changelog](CHANGELOG.md) for the full list.

The MIT license is retained unchanged and the upstream copyright notice is
preserved in [LICENSE](LICENSE). Upstream remains configured as a git remote so
improvements can be taken deliberately:

```bash
git fetch upstream
git log --oneline main..upstream/main     # what upstream has that we do not
git merge upstream/main                   # when it is worth taking
```

---

## License

MIT. Use it, change it, run it in your restaurant, sell services around it.
Keep the copyright notice. See [LICENSE](LICENSE).
