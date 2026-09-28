#!/usr/bin/env bash
# =============================================================================
# worktree.sh — create, inspect, reset and remove isolated agent worktrees
# =============================================================================
#
# Usage:
#   worktree.sh create   [--agent NAME] [--task TASK-ID] [--base REF]
#   worktree.sh list
#   worktree.sh status   [--agent NAME]
#   worktree.sh claim    --task TASK-ID [--agent NAME]
#   worktree.sh run      --task TASK-ID -- CMD...
#   worktree.sh report   --task TASK-ID --summary "text"
#   worktree.sh reset    [--agent NAME] [--hard]
#   worktree.sh remove   [--agent NAME] [--force]
#   worktree.sh ports    [--agent NAME]
#   worktree.sh doctor
#
# Every command is safe to run twice. `create` reuses an existing worktree
# rather than resetting it, `remove` refuses to discard uncommitted work without
# --force, and `reset` defaults to discarding nothing.

set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

AGENT="$(agent_name)"
TASK=""
BASE=""
FORCE="no"
HARD="no"
SUMMARY=""

usage() {
  sed -n '3,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

# --- Argument parsing --------------------------------------------------------
# Hand-rolled so the script runs identically in Git Bash, macOS and Linux with
# no getopt dependency, and so `--` passthrough for `run` behaves predictably.
COMMAND="${1:-}"
[ -n "$COMMAND" ] || usage 1
shift || true

PASSTHROUGH=()
while [ $# -gt 0 ]; do
  case "$1" in
    --agent) AGENT="$(require_slug 'agent name' "$(slugify "$2")")"; shift 2 ;;
    --task)  TASK="$(require_slug 'task id' "$(slugify "$2")")"; shift 2 ;;
    --base)  BASE="$2"; shift 2 ;;
    --summary) SUMMARY="$2"; shift 2 ;;
    --force) FORCE="force"; shift ;;
    --hard)  HARD="hard"; shift ;;
    -h|--help) usage 0 ;;
    --) shift; PASSTHROUGH=("$@"); break ;;
    *) die "Unknown argument: $1 (try --help)" ;;
  esac
done

case "$COMMAND" in
  create)
    # Ports are reserved at create time, not at test time, so two agents created
    # in the same wave cannot end up competing for the same port later.
    create_worktree "$AGENT" "$TASK" "$BASE" >/dev/null
    DIR="$(agent_worktree "$AGENT")"
    BLOCK="$(reserve_port_block "$AGENT")"
    SCRATCH="$(agent_scratch "$AGENT")"
    log ""
    log "${C_BOLD}Agent:${C_RESET}    ${AGENT}"
    log "${C_BOLD}Worktree:${C_RESET} ${DIR}"
    log "${C_BOLD}Branch:${C_RESET}   $(agent_branch "$AGENT" "$TASK")"
    log "${C_BOLD}Ports:${C_RESET}    ${BLOCK}"
    log "${C_BOLD}Scratch:${C_RESET}  ${SCRATCH}"
    log ""
    log "Start work with:"
    dim "  cd \"${DIR}\""
    dim "  # ... edit, test, commit ..."
    ;;

  list)
    if [ ! -d "$WORKTREES_DIR" ]; then
      log "No worktrees yet."
      exit 0
    fi
    log "${C_BOLD}git worktrees:${C_RESET}"
    git -C "$ROOT" worktree list
    log ""
    log "${C_BOLD}Agent worktrees:${C_RESET}"
    printf '%-18s %-34s %-8s %-6s %s\n' "AGENT" "BRANCH" "HEAD" "STATE" "AHEAD/BEHIND"
    found=0
    for d in "$WORKTREES_DIR"/*; do
      [ -d "$d" ] || continue
      found=1
      worktree_status "$(basename "$d")"
    done
    [ "$found" = 1 ] || log "  (none)"
    ;;

  status)
    DIR="$(agent_worktree "$AGENT")"
    [ -d "$DIR" ] || die "No worktree for '${AGENT}'. Create one: worktree.sh create --agent ${AGENT}"
    log "${C_BOLD}Agent:${C_RESET}   ${AGENT}"
    log "${C_BOLD}Worktree:${C_RESET} ${DIR}"
    log "${C_BOLD}Branch:${C_RESET}  $(git -C "$DIR" rev-parse --abbrev-ref HEAD)"
    log "${C_BOLD}HEAD:${C_RESET}    $(git -C "$DIR" log --oneline -1)"
    log ""
    log "${C_BOLD}Working tree:${C_RESET}"
    if worktree_is_clean "$DIR"; then
      ok "  clean"
    else
      warn "  uncommitted changes:"
      git -C "$DIR" status --short
    fi
    log ""
    log "${C_BOLD}Commits ahead of origin/main:${C_RESET}"
    git -C "$DIR" log --oneline origin/main..HEAD 2>/dev/null | head -20 || log "  (none)"
    ;;

  claim)
    [ -n "$TASK" ] || die "claim requires --task TASK-ID"
    claim_task "$TASK" "$AGENT"
    ;;

  run)
    [ -n "$TASK" ] || die "run requires --task TASK-ID"
    [ "${#PASSTHROUGH[@]}" -gt 0 ] || die "run requires a command after --"
    DIR="$(agent_worktree "$AGENT")"
    [ -d "$DIR" ] || die "No worktree for '${AGENT}'. Create one first."
    LOG="${LOGS_DIR}/${AGENT}/${TASK}.log"
    mkdir -p "$(dirname "$LOG")"
    dim "  ${PASSTHROUGH[*]}"
    dim "  log: ${LOG}"
    # Capture to a per-agent log so two agents' output never interleaves in a
    # shared file, and so a failed run can be read after the fact.
    if ( cd "$DIR" && "${PASSTHROUGH[@]}" ) 2>&1 | tee "$LOG"; then
      ok "Command succeeded."
    else
      die "Command failed. Log: ${LOG}"
    fi
    ;;

  report)
    [ -n "$TASK" ] || die "report requires --task TASK-ID"
    [ -n "$SUMMARY" ] || die "report requires --summary \"text\""
    write_report "$AGENT" "$TASK" "$SUMMARY"
    ;;

  reset)
    DIR="$(agent_worktree "$AGENT")"
    [ -d "$DIR" ] || die "No worktree for '${AGENT}'."
    if [ "$HARD" = "hard" ]; then
      warn "Discarding all uncommitted changes in ${DIR}."
      git -C "$DIR" checkout -- . 2>/dev/null || true
      git -C "$DIR" clean -fd 2>/dev/null || true
      ok "Worktree reset to HEAD."
    else
      log "Reset is a no-op unless --hard is given. Nothing was changed."
      log "Current state:"
      git -C "$DIR" status --short | head -20
    fi
    ;;

  remove)
    remove_worktree "$AGENT" "$FORCE"
    ;;

  ports)
    if [ -d "${LOCKS_DIR}/ports" ]; then
      log "${C_BOLD}Port reservations:${C_RESET}"
      printf '%-8s %s\n' "PORT" "AGENT"
      for d in "${LOCKS_DIR}/ports"/*; do
        [ -d "$d" ] || continue
        printf '%-8s %s\n' "$(basename "$d")" "$(cat "${d}/agent" 2>/dev/null || echo '?')"
      done
    else
      log "No port reservations."
    fi
    ;;

  doctor)
    # Answers "why will this not run" before the operator has to ask.
    log "${C_BOLD}Harness doctor${C_RESET}"
    log ""
    log "Repository root:  ${ROOT}"
    log "Harness dir:      ${HARNESS_DIR}"
    log ""
    check() {
      local label="$1"; shift
      if "$@" >/dev/null 2>&1; then
        printf '  %sok%s    %s\n' "$C_GREEN" "$C_RESET" "$label"
      else
        printf '  %sFAIL%s  %s\n' "$C_RED" "$C_RESET" "$label"
      fi
    }
    check "git available"              command -v git
    check "git identity configured"    require_git_identity
    check "inside a git work tree"     git -C "$ROOT" rev-parse --git-dir
    check "git worktree supported"     git -C "$ROOT" worktree list
    check "curl available"             command -v curl
    check "unzip available"            command -v unzip
    check "PocketBase binary present"  test -f "$(pocketbase_path)"
    check "jq present (cached)"        test -f "$(jq_path)"
    check "jq runs"                    "$(jq_path)" --version
    log ""
    if [ -f "$(pocketbase_path)" ]; then
      dim "  PocketBase: $(pocketbase_path)"
      "$(pocketbase_path)" --version 2>/dev/null | sed 's/^/    /' || true
    else
      dim "  Run: .harness/scripts/setup-tools.sh"
    fi
    if command -v flutter >/dev/null 2>&1; then
      printf '  %sok%s    flutter on PATH: %s\n' "$C_GREEN" "$C_RESET" "$(command -v flutter)"
      printf '        %s\n' "$(flutter --version 2>/dev/null | head -1 || echo '?')"
    else
      printf '  %swarn%s  flutter not on PATH (needed only for app tests/builds)\n' "$C_YELLOW" "$C_RESET"
      # A Flutter SDK cloned but not exported is the common case on a fresh
      # machine, and "not on PATH" alone sends people looking for a reinstall
      # when the fix is one export line.
      for candidate in "$HOME/flutter/bin" "/c/flutter/bin" "C:/flutter/bin"; do
        if [ -x "${candidate}/flutter" ] || [ -x "${candidate}/flutter.bat" ]; then
          dim "        found an SDK at ${candidate} — add it to PATH:"
          dim "          export PATH=\"${candidate}:\$PATH\""
          break
        fi
      done
    fi
    ;;

  *) usage 1 ;;
esac
