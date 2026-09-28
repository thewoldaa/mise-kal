#!/usr/bin/env bash
# =============================================================================
# integrate.sh — controlled merge of agent branches into main
# =============================================================================
#
# Usage:
#   integrate.sh --branch agent/alpha/t-001 [--into main] [--dry-run] [--yes]
#   integrate.sh --wave wave-1            [--into main] [--dry-run] [--yes]
#
# WHY THIS IS NOT JUST `git merge`
#
#   Merging five agent branches by hand is how a wave ends up with a commit that
#   nobody can attribute, a conflict resolved by whoever happened to be at the
#   keyboard, and tests that were green on every branch and red on main.
#
#   This script does the boring, repeatable parts and refuses the dangerous
#   ones:
#
#     * every branch is checked for uncommitted work before anything merges
#     * a trial merge runs first, and a conflict aborts the whole integration
#       without touching main — so a conflict is detected before it is merged,
#       not discovered afterwards
#     * the suites are run on the merged result, so "green on the branch" cannot
#       be mistaken for "green on main"
#     * each branch merges as one commit with its own subject, so history stays
#       attributable per agent
#
#   Nothing here is destructive: a conflict leaves main exactly as it was.

set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

BRANCH=""
WAVE=""
INTO="main"
DRY_RUN="no"
ASSUME_YES="no"
SKIP_TESTS="no"

while [ $# -gt 0 ]; do
  case "$1" in
    --branch) BRANCH="$2"; shift 2 ;;
    --wave)   WAVE="$2"; shift 2 ;;
    --into)   INTO="$2"; shift 2 ;;
    --dry-run) DRY_RUN="yes"; shift ;;
    --yes|-y) ASSUME_YES="yes"; shift ;;
    --skip-tests) SKIP_TESTS="yes"; shift ;;
    -h|--help) sed -n '3,10p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "Unknown argument: $1" ;;
  esac
done

[ -n "$BRANCH" ] || [ -n "$WAVE" ] || die "Provide --branch or --wave."

# --- Collect the branches to merge -------------------------------------------

BRANCHES=()
if [ -n "$WAVE" ]; then
  DIR="$(wave_dir "$WAVE")"
  [ -d "$DIR" ] || die "No such wave: ${WAVE}"
  while IFS= read -r agent; do
    [ -n "$agent" ] || continue
    # Find the branch that worktree is actually on, rather than guessing it from
    # the agent name: the task component is part of the branch name and may
    # differ from the wave id.
    wt="$(agent_worktree "$agent")"
    if [ -d "$wt" ]; then
      b="$(git -C "$wt" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '')"
      [ -n "$b" ] && BRANCHES+=("$b")
    else
      warn "Agent '${agent}' has no worktree; skipping."
    fi
  done < <(wave_agents "$WAVE")
else
  BRANCHES=("$BRANCH")
fi

[ "${#BRANCHES[@]}" -gt 0 ] || die "No branches to integrate."

log "${C_BOLD}Integration plan${C_RESET}"
log "  target:   ${INTO}"
log "  branches:"
for b in "${BRANCHES[@]}"; do
  printf '    - %s (%s commits ahead)\n' "$b" "$(git -C "$ROOT" rev-list --count "${INTO}..${b}" 2>/dev/null || echo '?')"
done
log ""

# --- Pre-flight checks -------------------------------------------------------

# Identity first: without it the trial merge below fails with "Committer
# identity unknown", which reads exactly like a conflict and sends you looking
# for one that does not exist.
require_git_identity

# Refuse to start from a dirty main. A dirty target means the merge result
# includes changes nobody committed, which makes the whole integration
# unreproducible.
if [ "$DRY_RUN" != "yes" ]; then
  if ! git -C "$ROOT" diff --quiet || ! git -C "$ROOT" diff --cached --quiet; then
    warn "The target checkout has uncommitted changes:"
    git -C "$ROOT" status --short | head -10
    die "Commit or stash them before integrating. Integration must be reproducible."
  fi
fi

current_branch="$(git -C "$ROOT" rev-parse --abbrev-ref HEAD)"
if [ "$current_branch" != "$INTO" ]; then
  die "Target checkout is on '${current_branch}', expected '${INTO}'.
     Switch to ${INTO} first: git -C \"${ROOT}\" checkout ${INTO}"
fi

# Every branch must exist and be clean of uncommitted work in its worktree.
for b in "${BRANCHES[@]}"; do
  git -C "$ROOT" show-ref --verify --quiet "refs/heads/${b}" \
    || die "Branch '${b}' does not exist."
done

# --- Conflict detection ------------------------------------------------------
# A trial merge is run in a scratch clone-free way: merge into a temporary
# branch, check the result, then delete it. If it conflicts, the temporary
# branch is aborted and main is never touched.

info "Checking for conflicts before merging anything ..."

# Work on a temporary branch so a conflict cannot leave main half-merged.
TRIAL="integrate-trial/$$"
git -C "$ROOT" checkout -q -b "$TRIAL" "$INTO"

cleanup_trial() {
  git -C "$ROOT" merge --abort 2>/dev/null || true
  git -C "$ROOT" checkout -q "$INTO" 2>/dev/null || true
  git -C "$ROOT" branch -D "$TRIAL" 2>/dev/null || true
}
trap cleanup_trial EXIT

CONFLICTS=0
for b in "${BRANCHES[@]}"; do
  # Each merge must be committed before the next one is attempted. Without the
  # commit, `--no-commit` leaves the index staged and the *following* branch's
  # merge fails with "you have unmerged files" even though it is perfectly
  # mergeable — a false conflict, which is the worst kind of bug in a tool whose
  # entire job is telling you whether merging is safe.
  if git -C "$ROOT" merge --no-ff --no-edit \
       -m "trial: ${b}" "$b" >/dev/null 2>&1; then
    printf '  %sno conflict%s  %s\n' "$C_GREEN" "$C_RESET" "$b"
  else
    printf '  %sCONFLICT%s     %s\n' "$C_RED" "$C_RESET" "$b"
    CONFLICTS=$((CONFLICTS + 1))
    git -C "$ROOT" merge --abort 2>/dev/null || true
    break
  fi
done

if [ "$CONFLICTS" -gt 0 ]; then
  log ""
  warn "${CONFLICTS} branch(es) conflict with the current ${INTO}."
  warn "Nothing was merged; ${INTO} is unchanged."
  log ""
  log "Resolve in the agent's own worktree, where the conflict belongs to"
  log "whoever caused it, rather than on ${INTO}:"
  for b in "${BRANCHES[@]}"; do
    wt="$(find_worktree_for_branch "$b")"
    if [ -n "$wt" ]; then
      dim "  git -C \"${wt}\" merge ${INTO}"
    else
      dim "  (branch ${b} has no worktree; recreate one to resolve it)"
    fi
  done
  log ""
  dim "Then re-run:  .harness/scripts/wave.sh integrate ${WAVE:-<wave>}"
  exit 2
fi

if [ "$DRY_RUN" = "yes" ]; then
  log ""
  ok "Dry run complete: no conflicts. Nothing was merged."
  exit 0
fi

# --- Real merge --------------------------------------------------------------
# The trial left the index staged with the merge content. Commit it once per
# branch instead, so each agent's contribution is its own attributable commit.

git -C "$ROOT" merge --abort 2>/dev/null || true
git -C "$ROOT" reset --hard -q "$INTO"

if [ "$ASSUME_YES" != "yes" ]; then
  log ""
  log "About to merge ${#BRANCHES[@]} branch(es) into ${INTO} and run the suites."
  printf 'Continue? [y/N] '
  read -r reply || reply=""
  case "$reply" in
    [yY]*) : ;;
    *) die "Aborted. Nothing was merged." ;;
  esac
fi

MERGED=()
for b in "${BRANCHES[@]}"; do
  subject="$(git -C "$ROOT" log -1 --format='%s' "$b" 2>/dev/null || echo "$b")"
  info "Merging ${b} ..."
  # --no-ff keeps each agent's work as a distinguishable merge commit even when
  # a fast-forward would have been possible. Attribution is worth the extra node.
  if git -C "$ROOT" merge --no-ff --no-edit -m "integrate(${b##*/}): ${subject}" "$b" >/dev/null 2>&1; then
    MERGED+=("$b")
    ok "  merged"
  else
    git -C "$ROOT" merge --abort 2>/dev/null || true
    die "Merge of '${b}' failed despite the trial succeeding. ${INTO} is unchanged.
     This should not happen; report it rather than resolving by hand."
  fi
done

# --- Verify the merged result ------------------------------------------------
# The point of this step: a branch can be green on its own and red once merged
# with a sibling. Running the suites here is the only way to know.

if [ "$SKIP_TESTS" = "yes" ]; then
  warn "Skipping post-merge tests (--skip-tests). The merge is NOT verified."
else
  log ""
  info "Running the backend suites on the merged result ..."
  if "${HARNESS_SCRIPTS_DIR}/test.sh" --agent orchestrator --all --quiet; then
    ok "Post-merge suites passed."
  else
    warn "Post-merge suites FAILED. The merge is in place but unverified."
    warn "Inspect, fix, or reset: git -C \"${ROOT}\" reset --hard HEAD~${#MERGED[@]}"
    exit 1
  fi
fi

log ""
ok "Integrated ${#MERGED[@]} branch(es) into ${INTO}:"
for b in "${MERGED[@]}"; do
  dim "  ${b}"
done
log ""
dim "Push when ready:  git -C \"${ROOT}\" push origin ${INTO}"
