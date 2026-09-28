#!/usr/bin/env bash
# =============================================================================
# wave.sh — wave lifecycle: open, add agents, status, integrate, close
# =============================================================================
#
# A wave is a batch of agents working in parallel on tasks that do not depend on
# each other, followed by one controlled integration into main.
#
# Usage:
#   wave.sh open   WAVE-ID ["description"]
#   wave.sh add    WAVE-ID --agent NAME [--task TASK-ID]
#   wave.sh status WAVE-ID
#   wave.sh integrate WAVE-ID [--dry-run]
#   wave.sh close  WAVE-ID
#   wave.sh list

set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

COMMAND="${1:-}"
WAVE="${2:-}"
[ -n "$COMMAND" ] || die "Usage: wave.sh <open|add|status|integrate|close|list> WAVE-ID"

# `list` takes no wave id, so it must not be forced to have one.
if [ "$COMMAND" != "list" ]; then
  [ -n "$WAVE" ] || die "Missing WAVE-ID for '${COMMAND}'."
fi

# Shift past the command, and past the wave id when one was given. A bare
# `shift 2` aborts under `set -e` when only the command was supplied, which is
# exactly what `wave.sh list` does.
if [ -n "$WAVE" ]; then
  shift 2
else
  shift 1
fi

AGENT=""
TASK=""
DESCRIPTION=""
DRY_RUN="no"
while [ $# -gt 0 ]; do
  case "$1" in
    --agent) AGENT="$(require_slug 'agent name' "$(slugify "$2")")"; shift 2 ;;
    --task)  TASK="$(require_slug 'task id' "$(slugify "$2")")"; shift 2 ;;
    --dry-run) DRY_RUN="yes"; shift ;;
    -*) die "Unknown argument: $1" ;;
    # A bare positional after the wave id is the wave description, for `open`.
    *) DESCRIPTION="$1"; shift ;;
  esac
done

case "$COMMAND" in
  open)
    wave_create "$WAVE" "$DESCRIPTION"
    log "Wave directory: $(wave_dir "$WAVE")"
    log "Add agents with: wave.sh add ${WAVE} --agent NAME --task TASK-ID"
    ;;

  add)
    [ -n "$AGENT" ] || die "add requires --agent NAME"
    wave_add_agent "$WAVE" "$AGENT"
    if [ -n "$TASK" ]; then
      if task_exists "$TASK"; then
        claim_task "$TASK" "$AGENT"
      else
        warn "Task '${TASK}' does not exist yet; recorded the agent only."
      fi
    fi
    ok "Added '${AGENT}' to wave '${WAVE}'."
    ;;

  status)
    DIR="$(wave_dir "$WAVE")"
    [ -d "$DIR" ] || die "No such wave: ${WAVE}"
    log "${C_BOLD}Wave:${C_RESET} $(cat "${DIR}/DESCRIPTION.txt" 2>/dev/null || echo "${WAVE}")"
    log "${C_BOLD}State:${C_RESET} $(cat "${DIR}/STATUS.txt" 2>/dev/null || echo 'open')"
    log ""
    printf '%-18s %-34s %-8s %-6s %s\n' "AGENT" "BRANCH" "HEAD" "STATE" "AHEAD/BEHIND"
    while IFS= read -r agent; do
      [ -n "$agent" ] || continue
      worktree_status "$agent"
    done < <(wave_agents "$WAVE")
    ;;

  integrate)
    DIR="$(wave_dir "$WAVE")"
    [ -d "$DIR" ] || die "No such wave: ${WAVE}"
    if [ "$DRY_RUN" = "yes" ]; then
      info "Dry run: no branch will be merged."
    fi
    # Integration is delegated so the conflict-detection logic lives in exactly
    # one place and cannot drift between wave.sh and a manual merge.
    "${HARNESS_SCRIPTS_DIR}/integrate.sh" --wave "$WAVE" $([ "$DRY_RUN" = "yes" ] && printf -- '--dry-run')
    ;;

  close)
    DIR="$(wave_dir "$WAVE")"
    [ -d "$DIR" ] || die "No such wave: ${WAVE}"
    # A wave cannot close with agents still dirty: that means someone's work
    # exists only in a working tree and would be lost by the next cleanup.
    dirty=0
    while IFS= read -r agent; do
      [ -n "$agent" ] || continue
      wt="$(agent_worktree "$agent")"
      if [ -d "$wt" ] && ! worktree_is_clean "$wt"; then
        warn "Agent '${agent}' has uncommitted changes."
        dirty=$((dirty + 1))
      fi
    done < <(wave_agents "$WAVE")
    if [ "$dirty" -gt 0 ]; then
      die "${dirty} agent(s) still dirty. Commit their work or remove them explicitly."
    fi
    printf 'closed\n' > "${DIR}/STATUS.txt"
    date -u '+%Y-%m-%dT%H:%M:%SZ' > "${DIR}/closed_at" 2>/dev/null || date > "${DIR}/closed_at"
    ok "Wave '${WAVE}' closed."
    ;;

  list)
    if [ ! -d "$WAVES_DIR" ]; then
      log "No waves yet."
      exit 0
    fi
    printf '%-16s %-10s %s\n' "WAVE" "STATE" "DESCRIPTION"
    for d in "$WAVES_DIR"/*; do
      [ -d "$d" ] || continue
      id="$(basename "$d")"
      printf '%-16s %-10s %s\n' "$id" \
        "$(cat "${d}/STATUS.txt" 2>/dev/null || echo '?')" \
        "$(cat "${d}/DESCRIPTION.txt" 2>/dev/null || echo '')"
    done
    ;;

  *) die "Unknown command: ${COMMAND}" ;;
esac
