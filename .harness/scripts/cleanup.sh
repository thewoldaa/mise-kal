#!/usr/bin/env bash
# =============================================================================
# cleanup.sh — prune merged worktrees, stale locks and old scratch
# =============================================================================
#
# Usage:
#   cleanup.sh [--dry-run] [--keep-branches] [--all]
#
# WHAT IT WILL AND WILL NOT REMOVE
#
#   It removes worktrees whose branch is already merged into main, stale port
#   reservations, dead locks, and scratch directories older than a threshold.
#
#   It refuses, always, to remove:
#     * a worktree with uncommitted changes
#     * a branch with commits not yet merged into main (unless --all)
#
#   Uncommitted or unmerged work is the most expensive thing in this repository,
#   and a cleanup script that quietly eats it is worse than no cleanup script.
#   When in doubt this script prints what it would do and leaves it alone.

set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

DRY_RUN="no"
KEEP_BRANCHES="no"
ALL="no"
SCRATCH_MAX_AGE_DAYS=14

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN="yes"; shift ;;
    --keep-branches) KEEP_BRANCHES="yes"; shift ;;
    --all) ALL="yes"; shift ;;
    -h|--help) sed -n '3,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "Unknown argument: $1" ;;
  esac
done

[ "$DRY_RUN" = "yes" ] && info "Dry run: nothing will be removed."

removed_worktrees=0
removed_branches=0
kept=0

# --- Worktrees ---------------------------------------------------------------

if [ -d "$WORKTREES_DIR" ]; then
  for d in "$WORKTREES_DIR"/*; do
    [ -d "$d" ] || continue
    agent="$(basename "$d")"
    branch="$(git -C "$d" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '')"
    [ -n "$branch" ] || { warn "'${agent}': cannot determine branch; skipping."; kept=$((kept+1)); continue; }

    if ! worktree_is_clean "$d"; then
      warn "'${agent}': uncommitted changes — keeping. Commit or remove it yourself."
      kept=$((kept + 1))
      continue
    fi

    # Merged means: no commits on this branch that main does not already have.
    unmerged="$(git -C "$ROOT" rev-list --count "origin/main..${branch}" 2>/dev/null || echo '?')"
    if [ "$unmerged" != "0" ] && [ "$ALL" != "yes" ]; then
      warn "'${agent}': ${unmerged} unmerged commit(s) on '${branch}' — keeping."
      kept=$((kept + 1))
      continue
    fi

    if [ "$DRY_RUN" = "yes" ]; then
      log "  would remove worktree '${agent}' (branch '${branch}')"
    else
      git -C "$ROOT" worktree remove --force "$d" 2>/dev/null || rm -rf "$d"
      ok "  removed worktree '${agent}'"
    fi
    removed_worktrees=$((removed_worktrees + 1))

    # The branch is only deleted when its work is safely on main. `-d` (not -D)
    # so git itself refuses if it would lose commits — a second safety net under
    # the rev-list check above.
    if [ "$KEEP_BRANCHES" != "yes" ]; then
      if [ "$DRY_RUN" = "yes" ]; then
        log "  would delete branch '${branch}'"
      else
        if git -C "$ROOT" branch -d "$branch" >/dev/null 2>&1; then
          ok "  deleted branch '${branch}'"
          removed_branches=$((removed_branches + 1))
        else
          warn "  branch '${branch}' not merged; kept"
        fi
      fi
    fi
  done
fi

if [ "$DRY_RUN" != "yes" ]; then
  git -C "$ROOT" worktree prune >/dev/null 2>&1 || true
fi

# --- Stale locks -------------------------------------------------------------
# A lock whose owning process is gone, or that is older than the stale window,
# blocks every agent that needs it.

if [ -d "$LOCKS_DIR" ]; then
  for lock in "$LOCKS_DIR"/*.lock; do
    [ -d "$lock" ] || continue
    name="$(basename "$lock" .lock)"
    pid="$(cat "${lock}/pid" 2>/dev/null || echo '')"
    alive="no"
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then alive="yes"; fi
    age="$(lock_age_seconds "$lock")"
    if [ "$alive" = "no" ] || [ "$age" -gt "$LOCK_STALE_SECONDS" ]; then
      if [ "$DRY_RUN" = "yes" ]; then
        log "  would remove stale lock '${name}' (pid ${pid:-?}, age ${age}s)"
      else
        rm -rf "$lock"
        ok "  removed stale lock '${name}'"
      fi
    else
      dim "  lock '${name}' is live (pid ${pid}); keeping"
    fi
  done
fi

# --- Port reservations -------------------------------------------------------
# Reservations belong to a worktree. One with no worktree behind it is orphaned.

if [ -d "${LOCKS_DIR}/ports" ]; then
  for p in "${LOCKS_DIR}/ports"/*; do
    [ -d "$p" ] || continue
    port="$(basename "$p")"
    holder="$(cat "${p}/agent" 2>/dev/null || echo '')"
    if [ -n "$holder" ] && [ ! -d "$(agent_worktree "$holder")" ]; then
      if [ "$DRY_RUN" = "yes" ]; then
        log "  would release orphaned port ${port} (was '${holder}')"
      else
        rm -rf "$p"
        ok "  released orphaned port ${port}"
      fi
    fi
  done
fi

# --- Old scratch -------------------------------------------------------------
# Scratch holds test databases and suite logs. They are useful for a while after
# a failure and then they are just disk.

if [ -d "$LOGS_DIR" ]; then
  for agent_logs in "$LOGS_DIR"/*; do
    [ -d "$agent_logs" ] || continue
    agent="$(basename "$agent_logs")"
    # Never touch the scratch of a live agent.
    if [ -d "$(agent_worktree "$agent")" ]; then
      dim "  scratch for live agent '${agent}'; keeping"
      continue
    fi
    scratch="${agent_logs}/scratch"
    [ -d "$scratch" ] || continue
    if [ "$DRY_RUN" = "yes" ]; then
      log "  would remove scratch for '${agent}'"
    else
      rm -rf "$scratch"
      ok "  removed scratch for '${agent}'"
    fi
  done
fi

log ""
log "${C_BOLD}Cleanup summary${C_RESET}"
log "  worktrees removed: ${removed_worktrees}"
log "  branches deleted:  ${removed_branches}"
log "  worktrees kept:    ${kept}"
[ "$DRY_RUN" = "yes" ] && log "  (dry run — nothing was changed)"
exit 0
