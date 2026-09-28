# Testing Mise-Kal

Seven suites. Six exercise the server, one exercises the Dart application. All
of them run with a single command, and each backend suite spins up a throwaway
database on its own port and tears it down afterwards. None of them touch real
data.

```bash
.harness/scripts/test.sh --agent local --all
```

## What each suite covers

| Suite | Covers |
|---|---|
| `smoke` | Order numbering, modifier pricing, tax and service charge, voids, table release, and that a forged total is overwritten |
| `setup` | The first-run endpoints, and that bootstrap can never run twice |
| `kitchen` | A bill's status following its lines, and the guards that stop it touching bills which are not in service |
| `payments` | Part payments, settlement, discounts, and refusing money against a cancelled bill |
| `staff` | Resetting a forgotten PIN, and the guards that stop a manager seizing an owner's account or the venue losing its last owner |
| `guest` | Table-side ordering: that a guest sees only the menu, that no price comes from the request, and that a stranger on the wi-fi cannot put food on the pass |
| `app` | Dart: printing, reporting, the offline queue, and localization |

Running one suite:

```bash
.harness/scripts/test.sh --agent local --suite smoke
.harness/scripts/test.sh --agent local --app
```

## Why the harness patches the suites

The harness does not run upstream's suites directly. It generates a patched copy
of each one, outside the repository, and runs that. The originals are never
modified, so `git status` stays clean and upstream stays mergeable.

Three things in the upstream suites break the moment two agents run at once. All
three were confirmed by reading the scripts, not assumed:

| Problem | What happens | Fix |
|---|---|---|
| Hardcoded ports 8091–8098 | Two agents on the same suite fight over a port; one gets a connection refused that looks like a product bug | Each agent gets a reserved block from `harness.conf` |
| Literal `/tmp/g.json`, `/tmp/p.json` | Git Bash does **not** honour `TMPDIR` for a literal `/tmp` path (verified by experiment), so agents overwrite each other's responses | Scratch paths are rewritten to the agent's own directory |
| `pkill -f "pocketbase serve --dir=./pb_test_data"` | `pkill -f` matches the command line as a string. Every agent's server has the *same* relative arguments, so agent A's cleanup kills agent B's server mid-suite | The server's PID is captured and only that process is killed |

The third one is the worst, because it produces a failure in a test that had
already passed, which reads as a product bug rather than a harness bug.

### The patcher asserts

Every substitution is checked. If upstream renames a variable or restructures a
suite, `test.sh` fails loudly with the missing marker rather than silently
running an unisolated suite. A silent failure here would be blamed on the
product code, which is exactly the confusion the harness exists to prevent.

## The Dart side

```bash
cd app && flutter test
```

### A fake server on a real socket

The offline queue tests use a fake PocketBase speaking HTTP on a loopback socket
rather than a mock object. That is deliberate: what matters is that a real
`ClientException` with `statusCode == 0` comes back out of the SDK, because that
is what `isNetworkFailure` keys on to decide between keeping a write for retry
and dropping it as refused.

A mock would let a test assert that `create()` was called. It would not prove
that a dropped connection is distinguishable from a rejection, which is the
thing that actually decides whether a waiter's order survives.

The printer tests take the same approach, with a fake thermal printer on a real
socket.

### One trap worth knowing

`TestWidgetsFlutterBinding` installs a mock `HttpClient` that answers every
request with 400 and never opens a socket. Any test that needs real HTTP must
not call `ensureInitialized()`. This cost an afternoon to diagnose, so it is
written down here and in a comment at the top of the affected test file.

## Writing a test

A change without a test is not finished.

| You changed | Minimum |
|---|---|
| Money math, order state, or anything in `pb_hooks/lib_money.js` | `smoke` and `payments` |
| The guest routes | `guest` |
| Staff roles or guards | `staff` |
| Kitchen state | `kitchen` |
| Flutter code | `flutter test`, plus a test for the new behaviour |
| Schema | `smoke` and `payments`, plus a new migration |

Two rules that matter more than coverage:

**Never weaken a test to make it pass.** If a test is wrong, fix it and say so in
the commit body. If it is right, your change is wrong.

**A flaky test is a bug.** Report it rather than re-running until it passes.

## Proving a fix is load-bearing

When a test is written for a bug fix, revert the fix and confirm the test fails.
A test that passes with and without the fix proves nothing and will not catch the
bug coming back.

This is not a formality. While writing the first tests for the offline queue, a
test was written for a suspected ordering bug that turned out not to exist. The
trace showed the queue kept its order correctly. The honest outcome was to delete
the test rather than keep a green assertion that guarded nothing.
