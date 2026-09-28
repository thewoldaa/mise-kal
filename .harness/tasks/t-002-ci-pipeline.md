---
id: t-002-ci-pipeline
title: Add a CI pipeline that runs both suites on every push
status: ready
owner: -
wave: 1
priority: high
depends_on: -
areas: [.github, .harness]
---

# Objective

A GitHub Actions workflow that runs all six backend suites and the Dart tests on
every push and pull request, on a clean machine, and fails the build when any of
them fails.

# Why

The repository currently has no automated check. Every guarantee in `PLAN.md` —
that money is computed server-side, that a forged total is overwritten, that a
venue cannot be left without an owner — is enforced only by a test suite that
somebody has to remember to run.

That is the difference between a rule and a hope. CI is also what makes the
wave model safe: a wave's integration should be rejected by the machine, not by
the orchestrator's memory.

# Scope

**In scope**

- A workflow that runs on `push` and `pull_request`.
- Backend suites: `smoke setup kitchen payments staff guest`.
- Dart tests via `flutter test`.
- A job that fails if `.harness/` runtime state or any credential-looking file
  is ever committed.

**Out of scope**

- Release automation and artifact publishing.
- Code signing.
- Windows packaging.

# Files and areas you may touch

```
.github/workflows/       allowed (create)
.harness/scripts/        allowed only if a CI-specific need genuinely requires it
README.md                allowed (add the badge)
```

# Dependencies

None, but coordinate with `t-001-windows-paths`: if that task changes a script
CI calls, this workflow must call the changed version.

# Acceptance criteria

- [ ] Workflow runs on push to `main` and on every pull request.
- [ ] All six backend suites run and their failure fails the job.
- [ ] `flutter test` runs and its failure fails the job.
- [ ] The workflow caches the PocketBase and Flutter downloads, so a run does not
      re-download ~250 MB every time.
- [ ] A secret-scanning step fails the build if a file matching credential
      patterns (`*.pem`, `.env`, `*_secret*`, `*token*.json`) is tracked.
- [ ] The workflow is green on the current `main`.

# Test requirement

The workflow is the test. It must be observed green on a real push before this
task is reported done. "It should work" is not acceptable for CI.

If a suite is genuinely impossible to run in CI, it must be explicitly skipped
with a comment saying why, not silently omitted.

# Commit requirement

- Subject: `ci: ...`
- The commit body states which suites run and what is deliberately excluded.

# Report requirement

Include a link to a green workflow run. If the run is not green, the task is not
done — say so plainly rather than reporting it as complete.
