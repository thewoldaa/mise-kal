# Installing on Windows

Two paths: run it from source, or build an application a restaurant can install.

## Running from source

Requirements:

- **Flutter 3.47 or later**, on `PATH`. `flutter --version` should answer before
  you start.
- **Git for Windows**, which brings Git Bash. Run everything from Git Bash, not
  PowerShell or cmd: every script in this repository is a POSIX shell script.
- **Nothing else.** PocketBase is downloaded on demand into `server/bin/`.

```bash
git clone https://github.com/thewoldaa/mise-kal.git
cd mise-kal

# Terminal 1 - the server
./server/scripts/dev.sh

# Terminal 2 - the application
cd app && flutter run -d windows
```

The first run fetches the pinned PocketBase and applies the schema migrations.
The admin interface is then at `http://127.0.0.1:8090/_/`. On first launch, point
the application at `127.0.0.1:8090`.

## Building the application

```bash
installer/windows/build_windows.sh
```

This produces a runnable build at
`app/build/windows/x64/runner/Release/Mise.exe`, with PocketBase staged into it
so the application starts its own server on first run.

### Developer Mode is required

Flutter creates symlinks under `windows/flutter/ephemeral/.plugin_symlinks` for
every native plugin. Windows refuses to create symlinks without Developer Mode,
and Flutter's own failure message does not name the prerequisite:

```
Building with plugins requires symlink support.
```

This project has five Windows plugins — `bonsoir_windows`, `jni`,
`path_provider_windows`, `shared_preferences_windows`, and
`windows_file_picker` — so the requirement cannot be avoided by dropping a
dependency.

Enable it once, as an administrator:

```
start ms-settings:developers
```

Or from an elevated PowerShell:

```powershell
New-Item -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' -Force
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' `
  -Name AllowDevelopmentWithoutDevLicense -Value 1 -Type DWord
```

`build_windows.sh` checks for this before doing anything and explains the fix,
rather than letting the build fail halfway through.

## An installer

Not built yet. `build_windows.sh` produces a runnable build; wrapping it in an
installer needs Inno Setup or NSIS, which is a decision that has not been made.

A half-built installer that silently produces a broken artifact is worse than
none, so the runnable build is the thing being verified first.

## The SmartScreen warning

A built `Mise.exe` is unsigned. Windows will show a SmartScreen warning the first
time it runs:

> Windows protected your PC

Choose **More info**, then **Run anyway**. You only do this once.

This is a cosmetic-trust problem, not a functional one. Removing it needs a
code-signing certificate, which costs a few hundred dollars a year. The project
ships unsigned deliberately and documents the workaround until signing is worth
paying for.

## Things that will bite you

These cost real time to diagnose, and each one is Windows-specific.

**Shell scripts must stay LF.** Git's default `core.autocrlf=true` rewrites
`.sh` files to CRLF on checkout, and bash then reads `set -euo pipefail\r`,
fails to find a command named `pipefail\r`, and dies before the script's first
line. `.gitattributes` pins the line ending in the repository so this cannot
happen. If you add a shell script and it fails strangely, check its endings
first.

**Git Bash does not honour `TMPDIR` for a literal `/tmp` path.** A script writing
to `/tmp/x.json` writes to the real
`C:\Users\<you>\AppData\Local\Temp`, not to whatever you set `TMPDIR` to. The
harness moves those paths into each agent's own scratch directory for exactly
this reason.

**`pkill -f` matches command lines as strings, not processes.** Two test runs in
different directories start PocketBase with identical relative arguments, so one
run's cleanup kills the other's server mid-suite. The harness kills by PID.

**A missing git identity does not stop you editing, only committing.** If
`git config user.name` is empty, the first commit fails with `Committer identity
unknown`, and in a merge that reads like a conflict. Set it once:

```bash
git config user.name "Your Name"
git config user.email "you@example.com"
```

`worktree.sh doctor` checks for this along with everything else.

## Checking your machine

```bash
.harness/scripts/setup-tools.sh
.harness/scripts/worktree.sh doctor
```

`doctor` reports what is present, what is missing, and where it found a Flutter
SDK that is not on `PATH`.
