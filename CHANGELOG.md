# Changelog

All notable changes to Mise-Kal are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Mise-Kal forked from [Mise](https://github.com/devShakib015/mise) at upstream
`main` commit `c56d1c3`. Versions before `0.1.0` are upstream's; Mise-Kal's own
history starts at `0.1.0`.

## [Unreleased]

### Planned

- Indonesian localization across the POS, KDS, and Manager shells (Phase 2)
- Windows installer (Phase 1)
- CI running both suites on every push

## [0.1.0] - 2026-09-28

The first Mise-Kal release. Everything here is infrastructure and correctness:
no product features were added, because stabilising the existing system and
making it testable comes before building on top of it.

### Added

**Multi-agent worktree harness** (`.harness/`)

An isolated git worktree, branch, reserved port block, and scratch directory per
agent, so several can work in parallel without touching each other's files.
Includes a wave lifecycle with controlled integration: a trial merge detects
conflicts before anything lands on `main`, each branch merges as its own
attributable commit, the full suite runs on the merged result, and each branch
is verified to be an ancestor of `main` afterwards.

- `worktree.sh` - create, list, status, claim, run, report, reset, remove, doctor
- `test.sh` - runs all suites with per-agent isolation
- `wave.sh`, `integrate.sh` - wave lifecycle and controlled merging
- `cleanup.sh` - prunes merged worktrees, stale locks, orphaned port reservations
- `setup-tools.sh` - fetches PocketBase and jq into a git-ignored cache
- `security-check.sh` - fails the build if a credential or private file is tracked

**Documentation**

- `CONTRIBUTING.md` - the workflow contract
- `SECURITY.md` - threat model and the guarantees the code is built to keep
- `AGENTS.md` - how an AI agent works in this repository
- `docs/architecture.md` - system structure and where future work attaches
- `.env.example` - configuration template with no values
- Task definitions in `.harness/tasks/` covering the first three phases

**Indonesian localization infrastructure**

Flutter `gen-l10n` with Indonesian as the template locale and English as the
fallback, 204 keys, and the connect and sign-in screens translated. The
generated Dart is committed so tests and CI need no codegen step.

**Windows build script** (`installer/windows/build_windows.sh`)

Produces a runnable Windows build with PocketBase staged in. Checks for
Developer Mode first and explains the fix, because Flutter's own failure for
that prerequisite does not name it.

### Fixed

- **Connection monitor could write to a disposed provider.** The health poll
  runs every ten seconds and takes up to four to answer, so the provider can be
  disposed while a request is in flight: the app closing, or a tablet signing
  out. Writing `state` after that threw `Cannot use the Ref of
  NotifierProvider after it has been disposed`. Three paths needed guarding:
  `check()` after its await, the periodic timer whose tick can already be
  queued, and `reportFailure`/`reportSuccess`.

- **Shell scripts were checked out with CRLF on Windows.** Git's default
  `core.autocrlf=true` rewrites every `.sh` file, and bash then reads
  `set -euo pipefail\r`, fails to find a command named `pipefail\r`, and dies
  before the first line. Line endings are now pinned in `.gitattributes`.

- **The vendored Inter font license was being reformatted.** A `.gitattributes`
  rule normalised the line endings of a third-party legal notice. It is now
  excluded from all git text processing.

### Changed

- Test suites run on Windows. Three things in upstream's suites break under
  concurrency, all confirmed by reading them: hardcoded ports 8091-8098, shared
  literal `/tmp` scratch files (Git Bash does not honour `TMPDIR` for a literal
  `/tmp` path), and `pkill -f` cleanup that matches command lines as strings and
  therefore kills a sibling agent's server. The harness patches a copy at run
  time with an absolute server path, a per-agent port and data directory, and
  PID-based cleanup, leaving the originals untouched so upstream stays
  mergeable.

- The repository carries project instructions and templates only. Personal
  agent instructions, memory, credentials, and machine-specific configuration
  are git-ignored, with a scanner that fails the build if any of it is tracked.

### Tests

101 backend checks across six suites, 74 Dart tests. The offline queue's
`flush()` gained 11 tests, having had none despite being the feature the product
leans on.

### Notes

Mise-Kal is a derivative work. The MIT license is retained unchanged and the
upstream copyright notice is preserved in `LICENSE`.

[Unreleased]: https://github.com/thewoldaa/mise-kal/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/thewoldaa/mise-kal/releases/tag/v0.1.0
