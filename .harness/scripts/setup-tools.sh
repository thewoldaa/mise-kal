#!/usr/bin/env bash
# =============================================================================
# setup-tools.sh — fetch the tools the harness needs, into .harness/cache/
# =============================================================================
#
# Nothing here is vendored into git. PocketBase and jq are downloaded on demand
# into .harness/cache/, which is git-ignored, exactly as upstream fetches
# PocketBase into server/bin/.
#
# Why jq is fetched rather than assumed:
#   Upstream's five backend test suites call bare `jq` to read fields out of
#   PocketBase JSON responses. jq is not installed on a stock Windows machine
#   and there is no package manager guaranteed to be present. Fetching the
#   single static binary into the cache and putting it on PATH for the duration
#   of a test run means the suites run unmodified on a clean machine.
#
# Safe to run repeatedly: each tool is skipped when the right version is already
# cached.

set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

POCKETBASE_VERSION="$(cat "${ROOT}/server/VERSION" 2>/dev/null || echo '0.40.1')"
JQ_VERSION="1.7.1"

detect_os() {
  case "$(uname -s)" in
    Darwin)               echo "darwin" ;;
    Linux)                echo "linux" ;;
    MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
    *) die "Unsupported OS: $(uname -s)" ;;
  esac
}

detect_arch() {
  case "$(uname -m)" in
    arm64|aarch64) echo "arm64" ;;
    x86_64|amd64)  echo "amd64" ;;
    *) die "Unsupported arch: $(uname -m)" ;;
  esac
}

OS="$(detect_os)"
ARCH="$(detect_arch)"

info "Platform: ${OS}/${ARCH}"

# --- PocketBase --------------------------------------------------------------
PB_DIR="$(tool_cache pocketbase)"
PB_BIN="$(pocketbase_path)"

if [ -f "$PB_BIN" ] && "$PB_BIN" --version 2>/dev/null | grep -q "$POCKETBASE_VERSION"; then
  ok "PocketBase ${POCKETBASE_VERSION} already cached."
else
  # Upstream only publishes amd64 for Windows and Linux; on those platforms a
  # non-amd64 machine falls back to amd64, which is what upstream's own fetch
  # script effectively assumes.
  ASSET_ARCH="$ARCH"
  if [ "$OS" != "darwin" ] && [ "$ARCH" != "amd64" ]; then
    warn "No ${ARCH} build published for ${OS}; using amd64."
    ASSET_ARCH="amd64"
  fi
  ASSET="pocketbase_${POCKETBASE_VERSION}_${OS}_${ASSET_ARCH}.zip"
  URL="https://github.com/pocketbase/pocketbase/releases/download/v${POCKETBASE_VERSION}/${ASSET}"
  info "Downloading ${ASSET} ..."
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT
  curl -fsSL "$URL" -o "${TMP}/pb.zip" || die "Download failed: ${URL}"
  unzip -qo "${TMP}/pb.zip" -d "${TMP}"
  # The archive contains the binary plus CHANGELOG/LICENSE at its root.
  find "${TMP}" -maxdepth 1 -type f -name 'pocketbase*' -exec cp {} "$PB_DIR/" \;
  chmod +x "$PB_DIR"/pocketbase* 2>/dev/null || true
  [ -f "$PB_BIN" ] || die "Extraction produced no binary in ${PB_DIR}"
  ok "PocketBase ${POCKETBASE_VERSION} ready at ${PB_BIN}"
fi

# --- jq ----------------------------------------------------------------------
JQ_DIR="$(tool_cache jq)"
JQ_BIN="$(jq_path)"

if [ -f "$JQ_BIN" ] && "$JQ_BIN" --version 2>/dev/null | grep -q "$JQ_VERSION"; then
  ok "jq ${JQ_VERSION} already cached."
else
  case "${OS}" in
    windows) JQ_URL="https://github.com/jqlang/jq/releases/download/jq-${JQ_VERSION}/jq-windows-amd64.exe"; JQ_OUT="${JQ_DIR}/jq.exe" ;;
    darwin)  JQ_URL="https://github.com/jqlang/jq/releases/download/jq-${JQ_VERSION}/jq-macos-amd64";     JQ_OUT="${JQ_DIR}/jq" ;;
    linux)   JQ_URL="https://github.com/jqlang/jq/releases/download/jq-${JQ_VERSION}/jq-linux-amd64";     JQ_OUT="${JQ_DIR}/jq" ;;
  esac
  info "Downloading jq ${JQ_VERSION} ..."
  curl -fsSL "$JQ_URL" -o "$JQ_OUT" || die "Download failed: ${JQ_URL}"
  chmod +x "$JQ_OUT" 2>/dev/null || true
  "$JQ_OUT" --version >/dev/null 2>&1 || die "Downloaded jq does not run: ${JQ_OUT}"
  ok "jq ${JQ_VERSION} ready at ${JQ_OUT}"
fi

log ""
ok "Tools ready. Suites will find them via:"
dim "  .harness/scripts/test.sh"
dim "  (which puts ${JQ_DIR} and ${PB_DIR} on PATH for the run)"
