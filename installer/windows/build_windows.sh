#!/usr/bin/env bash
# =============================================================================
# build_windows.sh — produce a Windows build with the server bundled
# =============================================================================
#
# Usage:
#   installer/windows/build_windows.sh [--debug]
#
# Output:
#   app/build/windows/x64/runner/Release/Mise.exe   (plus its data folder)
#
# WHAT THIS DOES NOT DO
#
#   It does not produce an installer .exe. That needs an installer toolchain
#   (Inno Setup or NSIS) which is a separate decision, and a half-built
#   installer that silently produces a broken artifact is worse than none.
#   This script produces a *runnable* build, which is the thing that has to
#   work before an installer is worth wrapping around it.
#
# PREREQUISITE: Developer Mode on Windows
#
#   `flutter build windows` fails with "Building with plugins requires symlink
#   support" unless Developer Mode is on, because Flutter creates symlinks under
#   windows/flutter/ephemeral/.plugin_symlinks for each native plugin. This
#   project has five Windows plugins (bonsoir_windows, jni, path_provider_windows,
#   shared_preferences_windows, windows_file_picker), so the requirement is not
#   avoidable by dropping a dependency.
#
#   Enable it once, as an administrator:
#       start ms-settings:developers
#   or, from an elevated PowerShell:
#       New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -Force
#       Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" `
#         -Name AllowDevelopmentWithoutDevLicense -Value 1 -Type DWord
#
#   This script checks for it first and explains what to do, rather than letting
#   Flutter fail with a message that does not name the fix.

set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.harness/scripts" && pwd)/lib.sh"

BUILD_MODE="release"
[ "${1:-}" = "--debug" ] && BUILD_MODE="debug"

cd "$ROOT"

# --- Preconditions -----------------------------------------------------------

info "Checking prerequisites"

if ! command -v flutter >/dev/null 2>&1; then
  # Look for a cloned SDK before telling someone to install one.
  for candidate in "$HOME/flutter/bin" "/c/flutter/bin"; do
    if [ -x "${candidate}/flutter" ] || [ -x "${candidate}/flutter.bat" ]; then
      die "Flutter is not on PATH, but an SDK exists at ${candidate}.
     Add it and re-run:
       export PATH=\"${candidate}:\$PATH\""
    fi
  done
  die "Flutter is not on PATH. Install it, or add an existing SDK to PATH."
fi

# Developer Mode is the prerequisite Flutter does not name clearly.
dev_mode="no"
if command -v powershell >/dev/null 2>&1; then
  value="$(powershell -NoProfile -Command \
    "(Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' -ErrorAction SilentlyContinue).AllowDevelopmentWithoutDevLicense" \
    2>/dev/null | tr -d '\r' || echo '')"
  [ "$value" = "1" ] && dev_mode="yes"
fi

if [ "$dev_mode" != "yes" ]; then
  warn "Developer Mode does not appear to be enabled."
  warn "Flutter needs it to create plugin symlinks; the build will fail without it."
  log ""
  log "Enable it once, as an administrator:"
  dim "  start ms-settings:developers"
  log ""
  log "Or from an elevated PowerShell:"
  dim "  New-Item -Path 'HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\AppModelUnlock' -Force"
  dim "  Set-ItemProperty -Path 'HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\AppModelUnlock' \`"
  dim "    -Name AllowDevelopmentWithoutDevLicense -Value 1 -Type DWord"
  log ""
  die "Cannot build without it. Nothing was changed."
fi
ok "Developer Mode is on"

# --- Stage the server into the app -------------------------------------------
# A restaurant downloads one thing. Bundling PocketBase and the schema means the
# app can start its own server on first run, with no second download and no
# terminal. This is the same step the macOS build does.

info "Staging PocketBase into the app"
if [ ! -f "${ROOT}/server/bin/pocketbase.exe" ] && [ ! -f "${ROOT}/server/bin/pocketbase" ]; then
  warn "PocketBase not fetched yet; fetching now."
  ( cd "${ROOT}/server" && ./fetch_pocketbase.sh )
fi
( cd "${ROOT}/app" && ./scripts/bundle_server.sh )
ok "Server staged"

# --- Build -------------------------------------------------------------------

info "Building Windows (${BUILD_MODE})"
( cd "${ROOT}/app" && flutter build windows "--${BUILD_MODE}" )

# --- Verify the output actually exists ---------------------------------------
# `flutter build` can exit 0 in configurations where the expected artifact is
# not where this script says it is. Checking means a caller can trust the exit
# code rather than having to look.

OUT_DIR="${ROOT}/app/build/windows/x64/runner"
EXE="${OUT_DIR}/$( [ "$BUILD_MODE" = "release" ] && echo Release || echo Debug )/Mise.exe"

log ""
if [ -f "$EXE" ]; then
  ok "Built ${EXE}"
  du -sh "$(dirname "$EXE")" 2>/dev/null | awk '{print "  size: " $1}'
  log ""
  log "Run it with:"
  dim "  \"${EXE}\""
else
  warn "flutter build reported success but ${EXE} is missing."
  warn "Contents of ${OUT_DIR}:"
  ls -R "$OUT_DIR" 2>/dev/null | head -20 || true
  die "Build output not found where expected."
fi
