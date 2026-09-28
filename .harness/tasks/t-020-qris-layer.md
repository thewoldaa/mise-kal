---
id: t-020-qris-layer
title: Design and implement the QRIS payment integration layer
status: draft
owner: -
wave: 3
priority: high
depends_on: t-010-id-locale
areas: [server, app, docs]
---

# Objective

An abstraction for electronic payments that QRIS can be plugged into, without
changing how the existing cash/card flow works.

This task is deliberately written as **design first**. Read it fully before
writing any code.

# Why

QRIS is the dominant payment rail in Indonesia, and Mise-Kal's Phase 3 is a
payment integration layer. Getting this wrong is expensive in a specific way:
payment code that leaks into the POS shell is payment code that cannot be
tested without a screen, cannot be audited without a human, and cannot be
replaced when the provider changes.

# The architectural constraint that matters

`PLAN.md` states, and `server/pb_hooks/lib_money.js` enforces, that **money is
only ever computed on the server** and that a client cannot decide what a bill
costs. A QRIS integration must not weaken that.

That means:

- The amount sent to the payment provider is read from the server's own
  `orders.total`, never from a request body.
- The provider's callback is verified (signature or provider-side confirmation)
  before it is allowed to create a `payments` record.
- A forged callback must not be able to mark a bill paid. This needs a test.
- The existing `payments` collection and its `paid_amount`/`paid` rollup stay the
  single source of truth. QRIS adds a payment *method*, not a second ledger.

# Scope

**In scope**

- A provider-agnostic interface: create a charge, query its status, handle a
  callback.
- One concrete implementation (the provider is a decision to be recorded, not
  assumed).
- Server-side amount derivation and callback verification.
- Tests covering the forged-callback case.
- Configuration through a template file, never a committed credential.

**Out of scope**

- Storing provider credentials in the repository. Ever.
- Refunds.
- Any change to how a bill's total is calculated.

# Files and areas you may touch

```
server/pb_hooks/           allowed
server/pb_migrations/      allowed (new files only)
server/scripts/            allowed (new test suite)
app/lib/features/pos/      allowed
app/lib/data/              allowed
docs/                      allowed
config.example.*           allowed (create)
```

# Dependencies

`t-010-id-locale` merged, because the payment screens are user-facing and
Indonesian.

# Acceptance criteria

- [ ] A written design is committed **before** the implementation, stating the
      provider choice and why, the callback verification method, and what happens
      when the provider is unreachable.
- [ ] The amount charged is derived server-side. A test proves a tampered request
      cannot change it.
- [ ] An unsigned or wrongly-signed callback cannot create a payment. A test
      proves it.
- [ ] With no provider configured, the app behaves exactly as it does today —
      cash and card work, QRIS is simply unavailable. This must be a test.
- [ ] Credentials come from a template file and are absent from git.
- [ ] A QRIS payment lands in `payments` and rolls into `paid_amount`/`paid`
      through the existing hooks, with no second code path.

# Test requirement

```bash
.harness/scripts/test.sh --agent NAME --suite payments
.harness/scripts/test.sh --agent NAME --suite smoke
.harness/scripts/test.sh --agent NAME --all
```

A new suite `qris_test.sh` is required. It must cover: a successful charge, a
forged callback, a replayed callback, an amount mismatch, and the
provider-unreachable path.

The `smoke` and `payments` suites are mandatory and must be unchanged in
behaviour — this task adds a method, it does not alter existing money math.

# Commit requirement

- Design commit first: `docs(payments): ...`
- Then implementation: `feat(payments): ...`
- Never commit a real key, token, merchant ID or callback secret — not even in a
  test fixture. Use obvious fakes.

# Report requirement

State plainly what is not verified: whether the provider's sandbox was actually
used, whether a real callback was ever received, and what remains unproven. An
integration that has only ever been tested against a mock must say so.
