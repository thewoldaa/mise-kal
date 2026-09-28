#!/usr/bin/env bash
# =============================================================================
# test.sh — run upstream test suites with per-agent isolation
# =============================================================================
#
# Usage:
#   test.sh [--agent NAME] [--suite smoke|setup|kitchen|payments|staff|guest]
#           [--app] [--all] [--keep] [--quiet]
#
# WHY THIS SCRIPT PATCHES THE UPSTREAM SUITES
#
#   Upstream's suites were written for one developer on one machine. Three
#   things in them break the moment two agents run at once, and all three were
#   confirmed by reading the scripts rather than guessed at:
#
#   1. Hardcoded ports (8091-8098). Two agents running `smoke` simultaneously
#      fight over 8091 and one gets a connection refused that looks like a
#      product bug but is not.
#
#   2. Shared scratch files in a literal /tmp (grep: `-o /tmp/g.json`). Git Bash
#      does NOT honour TMPDIR for a literal /tmp path — verified by experiment —
#      so both agents write the same file and read each other's responses.
#
#   3. `cleanup() { pkill -f "pocketbase serve --dir=./pb_test_data" ... }`.
#      pkill -f matches the command line as a string. Two agents in different
#      directories run pocketbase with the *same relative* arguments, so the
#      command lines are identical and agent A's cleanup kills agent B's server
#      mid-suite. This one produces a failure in a test that had already passed.
#
#   The fix is to generate a patched copy of each suite, outside the repository,
#   with an absolute server path, the agent's own port, its own data and temp
#   directories, and PID-based cleanup instead of a pattern kill. The originals
#   are never modified, so `git status` stays clean and upstream can be merged.
#
#   The patcher asserts on every substitution. If upstream renames a variable or
#   restructures a suite, this script fails loudly with the expected marker
#   missing rather than silently running an unisolated test.

set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

AGENT="$(agent_name)"
SUITE=""
RUN_APP="no"
RUN_ALL="no"
KEEP="no"
QUIET="no"

while [ $# -gt 0 ]; do
  case "$1" in
    --agent) AGENT="$(require_slug 'agent name' "$(slugify "$2")")"; shift 2 ;;
    --suite) SUITE="$2"; shift 2 ;;
    --app)   RUN_APP="yes"; shift ;;
    --all)   RUN_ALL="yes"; shift ;;
    --keep)  KEEP="yes"; shift ;;
    --quiet) QUIET="yes"; shift ;;
    -h|--help) sed -n '3,10p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "Unknown argument: $1" ;;
  esac
done

# The tree under test: the agent's worktree when it has one, otherwise the
# current checkout. Running against the current checkout is the common case for
# a single developer and for CI.
WORKTREE="$(agent_worktree "$AGENT")"
if [ -d "$WORKTREE" ]; then
  SUBJECT="$WORKTREE"
else
  SUBJECT="$ROOT"
fi
SERVER_DIR="${SUBJECT}/server"

[ -d "$SERVER_DIR" ] || die "No server directory at ${SERVER_DIR}"

# --- Tools -------------------------------------------------------------------
if [ ! -f "$(pocketbase_path)" ] || [ ! -f "$(jq_path)" ]; then
  info "Tools missing; fetching."
  "${HARNESS_SCRIPTS_DIR}/setup-tools.sh"
fi
harness_export_path

# --- Ports -------------------------------------------------------------------
# Reserve this agent's block once, and hand the suites the ports from it. The
# reservation is per-agent, so a second agent running the same suite in its own
# worktree gets a different block and the two never touch the same port.
PORT_LIST="$(reserve_port_block "$AGENT")"

# --- PocketBase into the worktree --------------------------------------------
# The suites call `./bin/pocketbase` relative to server/. That directory is
# already git-ignored upstream, so placing the cached binary there is invisible
# to git and isolated per worktree.
ensure_server_binary() {
  mkdir -p "${SERVER_DIR}/bin"
  local target="${SERVER_DIR}/bin/pocketbase"
  local source
  source="$(pocketbase_path)"
  if [ -f "$source" ]; then
    # Copy only when missing or a different size, so repeated runs are cheap.
    if [ ! -f "$target" ] || [ "$(wc -c < "$target" 2>/dev/null || echo 0)" != "$(wc -c < "$source" 2>/dev/null || echo -1)" ]; then
      cp "$source" "$target"
    fi
    [ -f "${SERVER_DIR}/bin/pocketbase.exe" ] || cp "$source" "${SERVER_DIR}/bin/pocketbase.exe" 2>/dev/null || true
  else
    die "No cached PocketBase. Run .harness/scripts/setup-tools.sh"
  fi
}

# --- Suite patching ----------------------------------------------------------

# Assert that a pattern is present, then substitute it. A no-op substitution is
# treated as a hard failure: silently running an unisolated suite is worse than
# not running it, because the resulting failure gets blamed on the code.
patch_assert() {
  local file="$1"
  local pattern="$2"
  local replacement="$3"
  local label="$4"
  if ! grep -qF -- "$pattern" "$file"; then
    die "Patch '${label}' failed: marker not found in $(basename "$file"):
       ${pattern}
     Upstream likely changed. Update .harness/scripts/test.sh to match."
  fi
  # Use a non-slash delimiter because the replacement contains paths.
  sed -i "s|$(printf '%s' "$pattern" | sed 's/[][\\.*^$/&|]/\\&/g')|$(printf '%s' "$replacement" | sed 's/[&|\\]/\\&/g')|g" "$file"
}

patch_suite() {
  local suite="$1"
  local port="$2"
  local scratch="$3"
  local src="${SERVER_DIR}/scripts/${suite}_test.sh"
  local out="${scratch}/suites/${suite}_test.sh"

  [ -f "$src" ] || die "No such suite: ${src}"

  mkdir -p "${scratch}/suites" "${scratch}/data/${suite}" "${scratch}/tmp"
  cp "$src" "$out"
  # Strip CRLF if the checkout produced them; a stray \r makes bash look for a
  # command named `pipefail\r`. .gitattributes should prevent this, but a fresh
  # clone made before that file existed can still have them.
  sed -i 's/\r$//' "$out"
  chmod +x "$out"

  # 1. Anchor to the worktree's server dir absolutely, so the copy can live
  #    outside the repository without breaking `cd "$(dirname "$0")/.."`.
  patch_assert "$out" 'cd "$(dirname "$0")/.."' "cd \"${SERVER_DIR}\"" "cd anchor"

  # 2. Give this agent its own port. The port differs per suite, so this patches
  #    by pattern rather than by value.
  sed -i "s|^PORT=[0-9]*|PORT=${port}|" "$out"
  if ! grep -q "^PORT=${port}$" "$out"; then
    die "Patch 'port' failed for ${suite}: no ^PORT= line in ${src}"
  fi

  # 3. Give this agent its own database directory, absolutely.
  if grep -qE '^DATA=' "$out"; then
    sed -i "s|^DATA=.*|DATA=\"${scratch}/data/${suite}\"|" "$out"
    grep -q "^DATA=\"${scratch}/data/${suite}\"$" "$out" || die "Patch 'data dir' failed for ${suite}"
  fi

  # 4. Move literal /tmp scratch files into this agent's own directory.
  sed -i "s|/tmp/|${scratch}/tmp/|g" "$out"
  if grep -q '[^a-zA-Z]/tmp/' "$out"; then
    die "Patch 'tmp files' failed for ${suite}: a literal /tmp path remains"
  fi

  # 5. Replace the pattern-kill cleanup with a PID kill.
  #
  #    Why this matters: upstream's cleanup is
  #      pkill -f "pocketbase serve --dir=./pb_test_data"
  #    pkill -f matches the command line as a *string*. Every agent in every
  #    worktree starts pocketbase with the same relative --dir, so the command
  #    lines are identical and agent A's cleanup kills agent B's server halfway
  #    through B's suite. The failure lands in whichever check happened to be
  #    running, so it reads as a product bug rather than a harness bug.
  #
  #    The fix records the PID of the backgrounded server and kills exactly that
  #    one. The `&` sits on the continuation line, not on the `pocketbase serve`
  #    line, so the PID must be captured on the backgrounded line itself.
  if grep -q 'pkill -f' "$out"; then
    awk '
      !seen && /&[[:space:]]*$/ {
        print; print "PB_PID=$!"; seen = 1; next
      }
      { print }
    ' "$out" > "${out}.tmp" && mv "${out}.tmp" "$out"
    grep -q '^PB_PID=\$!' "$out" || die "Patch 'record PID' failed for ${suite}: no backgrounded line matched"

    # '@' is the sed delimiter because the replacement contains both '/' (in
    # 2>/dev/null) and '|' (in '|| true'), which would terminate a 's|...|' or
    # 's/.../' expression early.
    sed -i 's@^cleanup() {.*@cleanup() { [ -n "${PB_PID:-}" ] \&\& kill "${PB_PID}" 2>/dev/null || true; wait "${PB_PID}" 2>/dev/null || true; rm -rf "${DATA}"; }@' "$out"
    grep -q 'kill "${PB_PID}"' "$out" || die "Patch 'cleanup' failed for ${suite}"
    if grep -q 'pkill -f' "$out"; then
      die "Patch 'cleanup' incomplete for ${suite}: pkill -f still present"
    fi
  fi

  printf '%s' "$out"
}

# --- Running -----------------------------------------------------------------

declare -a RESULTS=()
RUN_STARTED="$(date +%s 2>/dev/null || echo 0)"

run_suite() {
  local suite="$1"
  local port="$2"
  local scratch="$3"
  local script
  script="$(patch_suite "$suite" "$port" "$scratch")"
  local log="${scratch}/../${suite}.log"
  mkdir -p "$(dirname "$log")"

  log ""
  info "=== suite: ${suite}  (port ${port}) ==="
  dim "  script: ${script}"
  dim "  log:    ${log}"

  local rc=0
  if [ "$QUIET" = "yes" ]; then
    if ( cd "$SERVER_DIR" && "$script" ) > "$log" 2>&1; then rc=0; else rc=$?; fi
    tail -3 "$log" || true
  else
    if ( cd "$SERVER_DIR" && "$script" ) 2>&1 | tee "$log"; then rc=0; else rc=$?; fi
  fi

  if [ "$rc" -eq 0 ]; then
    RESULTS+=("PASS  ${suite}")
    ok "  -> ${suite}: PASS"
  else
    RESULTS+=("FAIL  ${suite} (exit ${rc})")
    warn "  -> ${suite}: FAIL (exit ${rc})"
  fi
  return 0
}

# Which suites to run, in upstream's documented order. `guest` is included
# because it exists in the tree even though the README's loop omits it.
SUITES="smoke setup kitchen payments staff guest"

# --- Main --------------------------------------------------------------------

# `--suite` narrows to one; `--app` alone means "Dart tests only, no backend
# suites"; `--all` means everything. Getting this wrong makes `--app` quietly
# run six backend suites the caller did not ask for.
if [ -n "$SUITE" ]; then
  SUITES="$SUITE"
elif [ "$RUN_APP" = "yes" ] && [ "$RUN_ALL" != "yes" ]; then
  SUITES=""
fi

if [ -z "$SUITES" ] && [ "$RUN_APP" = "no" ] && [ "$RUN_ALL" = "no" ]; then
  die "Nothing to do. Pass --suite NAME, --all, or --app."
fi

SCRATCH="$(agent_scratch "$AGENT")"
ensure_server_binary

# Assign one port per suite from this agent's reservation, so two agents running
# the same suite never share a port. `set --` turns the space-separated
# reservation into positional parameters, which is the portable way to index a
# list without relying on arrays or on awk's field handling of trailing spaces.
set -- $PORT_LIST
PORT_COUNT=$#
PORT_INDEX=0
for s in $SUITES; do
  PORT_INDEX=$((PORT_INDEX + 1))
  if [ "$PORT_INDEX" -le "$PORT_COUNT" ]; then
    eval "port=\${$PORT_INDEX}"
  else
    # More suites than reserved ports: fall back to a free port for the extras.
    port="$(find_free_port)"
    reserve_port "$port" "$AGENT" || true
  fi
  run_suite "$s" "$port" "$SCRATCH"
done

# --- Dart tests --------------------------------------------------------------
if [ "$RUN_APP" = "yes" ] || [ "$RUN_ALL" = "yes" ]; then
  log ""
  info "=== app: flutter test ==="
  if ! command -v flutter >/dev/null 2>&1; then
    warn "flutter is not on PATH; skipping app tests."
    RESULTS+=("SKIP  app (no flutter)")
  else
    log_file="${SCRATCH}/flutter_test.log"
    rc=0
    if ( cd "${SUBJECT}/app" && flutter test ) 2>&1 | tee "$log_file"; then rc=0; else rc=$?; fi
    if [ "$rc" -eq 0 ]; then
      RESULTS+=("PASS  app")
      ok "  -> app: PASS"
    else
      RESULTS+=("FAIL  app (exit ${rc})")
      warn "  -> app: FAIL (exit ${rc})"
    fi
  fi
fi

# --- Summary -----------------------------------------------------------------
log ""
log "${C_BOLD}========================= SUMMARY =========================${C_RESET}"
failed=0
for r in "${RESULTS[@]}"; do
  case "$r" in
    PASS*) printf '  %s%s%s\n' "$C_GREEN" "$r" "$C_RESET" ;;
    FAIL*) printf '  %s%s%s\n' "$C_RED" "$r" "$C_RESET"; failed=$((failed + 1)) ;;
    *)     printf '  %s%s%s\n' "$C_YELLOW" "$r" "$C_RESET" ;;
  esac
done

if [ "$KEEP" != "yes" ]; then
  dim ""
  dim "  (scratch kept at ${SCRATCH}; pass --keep to suppress this note)"
fi

log ""
if [ "$failed" -eq 0 ]; then
  ok "All suites passed for agent '${AGENT}'."
  exit 0
else
  warn "${failed} suite(s) failed for agent '${AGENT}'. Logs in ${SCRATCH}"
  exit 1
fi
