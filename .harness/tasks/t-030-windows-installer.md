---
id: t-030-windows-installer
title: Produce a Windows installer that a stranger can run
status: ready
owner: -
wave: 2
priority: high
depends_on: t-001-windows-paths
areas: [installer, app, docs]
---

# Objective

A Windows installer that unpacks the app, bundles PocketBase, and offers the
same "run the restaurant on this computer" first-run choice the macOS DMG does.

# Why

Upstream ships a DMG and documents Windows packaging as still to do. Mise-Kal's
stated platform is Windows first. Without this, the project's primary platform
has no install path at all.

The macOS build has already solved the hard parts — staging the server into the
app, the first-run choice, the unsigned-build warning — and
`installer/macos/build_dmg.sh` plus `app/scripts/bundle_server.sh` are the
references to follow.

# Scope

**In scope**

- Staging PocketBase into the Windows build, the way `bundle_server.sh` does for
  macOS.
- Building the Windows release.
- An installer (NSIS, Inno Setup, or MSIX — the choice and its reasoning go in
  the commit body).
- A first-run experience equivalent to macOS's: choose to run the server on this
  machine, or enter an address.
- Documenting the SmartScreen warning the way `install-macos.md` documents
  Gatekeeper.

**Out of scope**

- Code signing. Upstream ships unsigned deliberately and documents the
  workaround; do the same.
- Auto-update.
- The Linux AppImage.

# Files and areas you may touch

```
installer/windows/       allowed (create)
installer/               allowed
app/scripts/             allowed
app/windows/             allowed
docs/                    allowed
```

# Dependencies

`t-001-windows-paths` merged — the build script must not itself be a source of
path bugs.

# Acceptance criteria

- [ ] `installer/windows/build_installer.sh` (or `.ps1`) produces an installer
      from a clean checkout.
- [ ] Installing on a machine with no Flutter, no Dart and no PocketBase yields a
      working app.
- [ ] The bundled PocketBase starts and the app connects to it.
- [ ] The first-run choice exists and matches the macOS behaviour.
- [ ] `docs/install-windows.md` explains the SmartScreen warning in plain
      language, in the same tone as `install-macos.md`.
- [ ] The installer is unsigned and the documentation says so honestly.
- [ ] Nothing in `installer/out/` is committed.

# Test requirement

```bash
.harness/scripts/test.sh --agent NAME --all
```

Plus a manual install on a clean machine, or a clean user profile. This is a
packaging task: the automated suites do not exercise the installer, so the
manual verification is the actual evidence. Say in the report exactly how it was
tested.

# Commit requirement

- Subject: `feat(installer): ...`
- Document the installer-technology choice and its trade-offs in the body.

# Report requirement

State what was tested manually and on what. If the installer was only ever run
on the development machine, say so — that is a materially weaker claim than a
clean-machine install, and the reader needs to know which one it was.
