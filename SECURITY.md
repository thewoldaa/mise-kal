# Security Policy

## Reporting a vulnerability

Open a private security advisory on GitHub:

    https://github.com/thewoldaa/mise-kal/security/advisories/new

Please do not open a public issue for a vulnerability. Include what you did, what
happened, and what you expected — enough for someone else to reproduce it.

There is no bug bounty. This is a free, self-hosted project maintained in the
open; reports are handled as time allows, but they are taken seriously.

## What is in scope

Mise-Kal is a POS that runs on a restaurant's own network. The threat model that
matters is:

- **A tampered client.** A tablet on the restaurant's wi-fi must not be able to
  change what a bill costs, mark a bill paid, or read another table's data.
- **A guest on the wi-fi.** Someone who scans a table QR code must reach exactly
  the three public guest routes and nothing else.
- **A staff member overstepping their role.** A manager must not be able to
  seize an owner's account.
- **Data at rest.** The restaurant's sales data must not be readable by someone
  who should not have it.

Out of scope: anything requiring physical access to the server machine, and
anything requiring an already-compromised operating system. If the host is
compromised, no application-level control survives.

## The guarantees the code is built to keep

These are enforced in `server/pb_hooks/` and covered by tests. A report that
shows one of them failing is a real finding.

| Guarantee | Where | Test |
|---|---|---|
| All money is computed server-side; a forged total is overwritten | `pb_hooks/lib_money.js` | `smoke` — "Client cannot forge a total" |
| A guest's order is priced from the database, never from the request | `pb_hooks/guest.pb.js` | `guest` — "priced from the database" |
| Guests reach only the public routes; all collections stay staff-only | `pb_hooks/routes.pb.js` | `guest` — "collections stay staff-only" |
| A manager cannot reset an owner's PIN | `pb_hooks/staff.pb.js` | `staff` — "manager cannot reset an owner" |
| The venue can never be left without an active owner | `pb_hooks/lib_staff.js` | `staff` — "cannot be demoted/switched off/deleted" |
| Bootstrap can never run twice | `pb_hooks/lib_setup.js` | `setup` |
| Money cannot be taken against a cancelled bill | `pb_hooks/orders.pb.js` | `payments` |

## Public repository hygiene

Mise-Kal is developed in a private workspace and published publicly. Keeping
private material out is treated as a security property, not a tidiness
preference.

**Never committed:**

- API keys, tokens, passwords, private keys, connection strings
- `.env` files with real values — `.env.example` is the committed template
- Personal agent instructions, memory files or private prompts
- Machine-specific configuration
- Any file naming a real person's private information

**How this is enforced:**

```bash
.harness/scripts/security-check.sh            # tracked files
.harness/scripts/security-check.sh --all      # also untracked
.harness/scripts/security-check.sh --history  # also committed history
```

It runs in CI on every push and fails the build on a finding. `.gitignore` is
the first line of defence; this script is the backstop, because a `.gitignore`
does nothing about a file already tracked before the pattern existed, or a
secret pasted into a tracked file's body.

**If a secret is committed by accident:** rotate it. Deleting the commit or
force-pushing does not un-leak it — the value is in history, in any clone, and
possibly already fetched by automated scrapers. Rotation is the only fix that
actually works.

## Operational guidance for a restaurant

The server is meant to run on the restaurant's own LAN. Two things follow:

- **Do not expose the server to the internet.** Table-side ordering works over
  the LAN by design. Publishing the server to the internet trades away the
  offline guarantee and the zero-cost guarantee at the same time. If remote
  access is ever needed, it is a deliberate decision with a tunnel or VPN in
  front, not a port forward.
- **Change the default credentials.** A fresh install creates an owner account.
  A POS with a known PIN on an open network is an open till.

## Supported versions

The project is pre-1.0 and moving. Security fixes land on `main`; there are no
backport branches. Run the latest `main` if you need a fix.

## Acknowledgements

Upstream **Mise** by K M Shahriar Hossain established the security posture this
project inherits — in particular the rule that money is only ever computed
server-side. See <https://github.com/devShakib015/mise>.
