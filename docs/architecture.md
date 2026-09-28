# Mise-Kal architecture

How the system is put together, why it is put together that way, and where the
seams are for future development.

This is the document to read before making a structural change. The four rules
in §3 are not style preferences — they are what the tests are protecting, and
breaking one silently is how a POS starts losing money.

---

## 1. Repository layout

```
mise-kal/
├── PLAN.md                  upstream's design contract (still authoritative)
├── README.md                what this project is, and how it differs from upstream
├── CONTRIBUTING.md          the workflow contract
├── SECURITY.md              threat model and the guarantees the code keeps
├── AGENTS.md                how an AI agent works in this repository
├── LICENSE                  MIT, with upstream's copyright preserved
├── .gitattributes           line endings, pinned (Windows correctness)
├── .gitignore               aggressive; see §8
├── .env.example             configuration template — no values, ever
│
├── .harness/                multi-agent development harness (Mise-Kal addition)
│   ├── README.md
│   ├── scripts/             worktree, wave, test, integrate, cleanup, security
│   ├── tasks/               task definitions with front matter
│   └── waves/               wave manifests
│
├── server/                  PocketBase: schema + all business rules
│   ├── VERSION              pinned PocketBase version
│   ├── pb_migrations/       the schema, version-controlled
│   ├── pb_hooks/            rules that cannot live on a client
│   ├── pb_public/           the guest-facing page
│   ├── scripts/             dev server + six test suites
│   └── fetch_pocketbase.sh  downloads the pinned binary (not vendored)
│
├── app/                     Flutter: one binary, three role-based shells
│   ├── lib/core/            design system, router, discovery, printing, reporting
│   ├── lib/data/            models, repositories, offline queue
│   ├── lib/features/        setup, auth, pos, kds, manager
│   └── test/                Dart tests
│
├── installer/               packaging (macOS today, Windows planned)
└── docs/                    owner guide, developer guide, install guides
```

## 2. The shape of the system

```
                    ┌─────────────────────────────────────┐
                    │  PocketBase (one binary, on-site)   │
                    │  ┌───────────────┐ ┌─────────────┐  │
   Flutter app ────▶│  │  migrations   │ │   hooks     │  │
   (POS/KDS/Manager)│  │  the schema   │ │ order no's  │  │
        │           │  │               │ │ ALL MONEY   │  │
        │           │  └───────────────┘ │ guards      │  │
        │           │        SQLite       │ audit       │  │
        │           │                     └─────────────┘  │
        │           │  realtime subscriptions              │
        │           └─────────────────────────────────────┘
        │                          ▲
        │                          │ HTTP (LAN only)
   ESC/POS over TCP 9100           │
   (thermal printers)      guest phone (QR, browser)
```

**One server, one binary.** PocketBase contains the database, authentication,
realtime subscriptions, file storage and an admin UI. There is no cloud service,
no account, no credit card. This is what makes the offline guarantee possible:
the server is a machine in the restaurant, so losing the internet does not lose
the POS.

**One app, three shells.** Not three downloads. The signed-in staff member's
role decides which shell they get. One codebase, one installer, one thing to
explain to a restaurant.

**The server owns every rule that involves money.** The client displays totals;
it never computes them.

## 3. The four rules

These are load-bearing. Each is enforced in code and covered by a test. Breaking
one silently is how a restaurant loses money, so they are stated here in full.

### Money is only ever computed on the server

`server/pb_hooks/lib_money.js` recomputes every order's totals on write. A
client that PATCHes a forged `total` has it overwritten. The client displays
numbers; it does not add them up.

*Why:* a POS must never let a tampered client decide what a bill costs. The
tablet is on the restaurant's wi-fi and could be anything.

*Test:* `smoke` — "Client cannot forge a total".

### Menu names and prices are snapshotted onto order lines

When an item is added to an order, its name and unit price are copied onto the
line. The line does not reference the menu item for pricing.

*Why:* editing tomorrow's menu must never rewrite yesterday's bill.

*Test:* `smoke` — line totals are asserted against snapshot values.

### Takings are counted by when a bill closed

Reports and shifts key on `closed_at`, not `created_at`.

*Why:* a table seated before a shift began and settled during it is that
shift's takings. Keying on creation credits the money to the wrong session and
leaves the drawer looking short.

*Test:* `payments` — settlement and shift figures.

### Ageing and status use separate colour channels

On the kitchen display, a ticket's **border and timer** carry how long it has
been waiting. Its **dots and chips** carry what state each item is in.

*Why:* merging them makes a late ticket full of cooking items unreadable — the
two meanings fight each other. Red frame plus blue dots reads correctly at a
glance.

*Test:* visual; documented in `docs/developing.md`.

## 4. Data model

PocketBase collections, defined as JS migrations so the schema is
version-controlled and reproducible on a fresh install.

| Collection | Holds |
|---|---|
| `restaurant` | Name, logo, address, phone, currency, tax rate, service charge |
| `staff` | Auth collection — name, PIN, role, active |
| `categories` | Name, sort order, image, active |
| `menu_items` | Category, name, description, price, image, prep time, active |
| `modifier_groups` | Name, min/max selectable, required |
| `modifiers` | Group, name, price delta |
| `menu_item_modifiers` | Which groups apply to which items |
| `tables` | Label, seats, zone, current status |
| `orders` | Number, type, table, staff, status, money columns, timestamps |
| `order_items` | Order, item, qty, unit price snapshot, modifiers, notes, status |
| `payments` | Order, method, amount, reference, staff |
| `shifts` | Staff, open/close times, opening and closing cash, variance |
| `printers` | Name, IP, port, role, paper width |
| `audit_log` | Who changed what, when — voids and discounts especially |

**Schema changes are additive migrations.** Never edit an applied migration: a
machine that already ran it would end up with a different schema from a fresh
install, and that difference is invisible until it corrupts something.

## 5. Layers

```
app/lib/features/     role shells: setup, auth, pos, kds, manager
        │             depends on ▼
app/lib/data/         models, repositories, offline queue, live queries
        │             depends on ▼
app/lib/core/         theme, printing, reporting, discovery, widgets
                      depends on nothing above it
```

The dependency direction is one-way. `core/` never imports from `features/`. A
feature that needs something from another feature is a sign the shared part
belongs in `data/` or `core/`.

**Printing** lives in `core/printing/` with an IO implementation and a stub, so
the web build compiles and can say plainly that a browser cannot open a raw
socket, rather than failing strangely.

**Offline** lives in `data/offline/`. Adding to a bill works offline and queues
to disk. Firing to the kitchen and settling a bill deliberately do *not*: the
kitchen screen is the thing being written to, and a total only the server
computes cannot honestly be guessed at on a tablet.

## 6. Where the seams are for new work

This is the map for the Mise-Kal roadmap. Each later phase attaches at a
specific place, and knowing which one keeps a feature from being woven through
everything.

| Phase | Attaches at | Note |
|---|---|---|
| Indonesian localization | `app/lib/core/` + all of `features/` | First task that touches every user-facing string; establishes the pattern |
| QRIS payments | `server/pb_hooks/` + `data/` | Adds a **payment method**, not a second ledger. Must not weaken §3 |
| WhatsApp notifications | `server/pb_hooks/` | Outbound, triggered by existing order events |
| Inventory | `server/pb_migrations/` + `pb_hooks/` | Schema change; recipe/depletion logic belongs server-side |
| Multi-branch | Everywhere | The largest change. Needs a design task before code |
| Owner dashboard | `features/` | Depends on multi-branch for anything cross-venue |
| Backup/sync | `server/` | Depends on multi-branch |
| Analytics | `core/reporting/` | Depends on reporting data being trustworthy |

**The rule for adding a feature:** it must consider security, data integrity,
offline behaviour, migration, backward compatibility, testing, maintainability
and deployment. A feature request is not a reason to break the architecture.

## 7. Testing

Seven suites, all runnable with one command:

```bash
.harness/scripts/test.sh --agent <you> --all
```

| Suite | Covers |
|---|---|
| `smoke` | Order numbering, modifier pricing, tax/service, voids, table release, forged totals |
| `setup` | First-run endpoints, bootstrap can never run twice |
| `kitchen` | Bill status follows its lines; guards against touching bills not in service |
| `payments` | Part payments, settlement, discounts, refusing money against a cancelled bill |
| `staff` | PIN reset, privilege guards, the venue cannot lose its last owner |
| `guest` | Table-side ordering: menu visibility, server-side pricing, route isolation |
| `app` | Dart: printing, reporting, offline queue |

**Why the harness patches the suites rather than running them directly.**
Upstream's suites hardcode ports, share literal `/tmp` files, and clean up with
`pkill -f` — all three break the moment two agents run at once. The harness
generates a patched copy with an absolute server path, a per-agent port, a
per-agent data directory and PID-based cleanup, leaving the originals untouched
so upstream stays mergeable. It asserts on every substitution, so an upstream
restructure fails loudly instead of silently running an unisolated suite.

## 8. Security and the public/private split

The repository is public. The development workspace is private. The separation
is enforced, not assumed:

- `.gitignore` covers secrets, personal agent material and machine-specific
  configuration.
- `.env.example` documents configuration without carrying values.
- `.harness/scripts/security-check.sh` fails the build if anything forbidden is
  tracked, and runs in CI on every push.

The full threat model — tampered client, guest on the wi-fi, staff overstepping,
data at rest — is in [SECURITY.md](../SECURITY.md), together with the table of
guarantees and the test that proves each one.

## 9. Development model

Work happens in **waves**. A wave is a set of agents working in parallel on
independent tasks, followed by one controlled integration into `main`.

```
Wave 1   alpha: task A     beta: task B     gamma: task C
              \                |                 /
               +---- integrate into main ------+
Wave 2   delta: reads Wave 1's result, builds on it
```

Each agent works in its own git worktree, on its own branch, with its own
reserved port block and scratch directory. Nothing is shared except git's object
store, which git already makes safe for concurrent use.

Integration is a single controlled step that: refuses to start from a dirty
`main`; runs a trial merge to detect conflicts *before* anything lands; merges
each branch as its own attributable commit; runs the full suite on the merged
result; and verifies that each branch is genuinely an ancestor of `main`
afterwards. That last check exists because an earlier version of the script
merged onto a temporary branch and reported success while leaving `main`
untouched.

See [`.harness/README.md`](../.harness/README.md) for the operating manual.

## 10. Porting

The architecture is deliberately modular so the system can be ported beyond
Windows. The pieces that would need attention:

- **Installer** — `installer/` is per-platform by design; macOS exists, Windows
  is planned.
- **Server hosting** — `app/lib/core/server/server_host.dart` already has IO and
  stub implementations, so a platform that cannot host the server degrades
  cleanly rather than failing.
- **Printing** — `core/printing/` has the same IO/stub split. A platform without
  raw sockets reports that it cannot print.
- **Discovery** — `core/discovery/` uses mDNS with a typing-the-address fallback
  that never goes away, because multicast is blocked on plenty of networks.

The pattern to follow: an IO implementation plus a stub, so the app compiles and
tells the truth on a platform that cannot do the thing.
