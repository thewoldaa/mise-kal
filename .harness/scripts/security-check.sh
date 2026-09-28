#!/usr/bin/env bash
# =============================================================================
# security-check.sh — fail if anything private is about to be committed
# =============================================================================
#
# Usage:
#   security-check.sh              # check tracked files and their content
#   security-check.sh --all        # also report risky untracked files
#   security-check.sh --history    # also scan committed history (slow)
#
# WHY THIS EXISTS
#
#   Mise-Kal is developed in a private workspace and published to a public
#   repository. `.gitignore` prevents most leaks, but a .gitignore is a
#   *default*: it does nothing about a file already tracked before the pattern
#   was added, nothing about `git add -f`, and nothing about a secret pasted
#   into the body of a tracked file.
#
#   This script is the backstop, and it is deliberately slightly over-eager. A
#   false positive costs one line in a report. A false negative costs a leaked
#   credential in public git history, where deleting it is not enough.
#
# PERFORMANCE NOTE
#
#   The obvious implementation — nested loops calling `grep` once per file per
#   pattern — spawns thousands of processes under Git Bash and takes minutes on
#   a 250-file repository. It is written instead as a single `grep -r` pass with
#   all patterns in one alternation, which is roughly two orders of magnitude
#   faster and therefore actually gets run.
#
# EXIT CODES
#   0  nothing found
#   1  something was found; the output names it

set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

SCAN_ALL="no"
SCAN_HISTORY="no"
while [ $# -gt 0 ]; do
  case "$1" in
    --all)     SCAN_ALL="yes"; shift ;;
    --history) SCAN_HISTORY="yes"; shift ;;
    -h|--help) sed -n '3,22p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "Unknown argument: $1" ;;
  esac
done

FINDINGS=0
finding() {
  FINDINGS=$((FINDINGS + 1))
  printf '  %sFOUND%s  %s\n' "$C_RED" "$C_RESET" "$1"
}

log "${C_BOLD}Security check${C_RESET}"
log ""

# --- Patterns ----------------------------------------------------------------
#
# Paths that must never be tracked, whatever their content. Matched against the
# git index, because the index is what gets pushed.
#
# .env.example and config.example.* are templates, not secrets — they are the
# whole point of the public/private split, so they are allowed through below.

FORBIDDEN_PATHS='(^|/)\.env$|(^|/)\.env\.|\.pem$|\.key$|\.p12$|\.pfx$|\.keystore$|\.jks$|\.mobileprovision$|(^|/)\.ssh/|(^|/)\.agents/|(^|/)\.claude/|(^|/)\.cursor/|(^|/)\.codex/|(^|/)CLAUDE\.md$|(^|/)CLAUDE\.local\.md$|credentials.*\.json$|service-account.*\.json$|secret.*\.json$|token.*\.json$|(^|/)pb_superuser|(^|/)notes/|(^|/)private/|\.harness/worktrees/|\.harness/logs/|\.harness/locks/|\.harness/cache/|\.harness/harness\.conf$|server/bin/|pb_data/'

# Content that looks like a credential. Deliberately broad: a match is a prompt
# to look, not a verdict.
#
# `AGENTS.md` is absent from the path list on purpose — unlike CLAUDE.md it is a
# committed, project-facing document here. Personal agent material is ignored by
# pattern (see .gitignore), not by filename.
SECRET_CONTENT='sk-ant-[A-Za-z0-9_-]{20,}|ghp_[A-Za-z0-9]{30,}|gho_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|AIza[0-9A-Za-z_-]{30,}|AKIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]{10,}|-----BEGIN [A-Z ]*PRIVATE KEY-----'

# Files that legitimately contain content resembling the above, or that are
# generated. Kept as short as possible; anything added here is a blind spot.
SKIP_CONTENT='(\.lock$|package-lock\.json|\.min\.js$|\.ttf$|\.png$|\.ico$|\.exe$|security-check\.sh$)'

is_allowed_template() {
  case "$1" in
    *.env.example)     return 0 ;;
    *config.example.*) return 0 ;;
    *example*.json)    return 0 ;;
  esac
  return 1
}

# --- 1. Forbidden paths in the index -----------------------------------------

info "1. Forbidden paths in the git index"

path_hits=0
while IFS= read -r path; do
  [ -n "$path" ] || continue
  if printf '%s' "$path" | grep -qE "$FORBIDDEN_PATHS"; then
    is_allowed_template "$path" && continue
    finding "tracked: ${path}"
    path_hits=$((path_hits + 1))
  fi
done < <(git -C "$ROOT" ls-files)

[ "$path_hits" -eq 0 ] && ok "  no forbidden paths are tracked"

# --- 2. Secret-looking content -----------------------------------------------
# One recursive grep over the tracked files, with every pattern in a single
# alternation. Path checks cannot catch a key pasted into a tracked file.

info "2. Secret-looking content in tracked files"

# `xargs` exits non-zero when grep finds nothing, and under `set -e` inside a
# pipeline that would abort the script on the success path. The count is
# captured with `|| true` so an empty result is a normal outcome, not a failure.
content_hits="$(
  git -C "$ROOT" ls-files -z \
    | grep -zEv "$SKIP_CONTENT" \
    | xargs -0 -r grep -lE "$SECRET_CONTENT" 2>/dev/null \
    | wc -l | tr -d ' '
)" || content_hits=0

if [ "$content_hits" -gt 0 ]; then
  # Re-run so the offending paths are actually named.
  git -C "$ROOT" ls-files -z \
    | grep -zEv "$SKIP_CONTENT" \
    | xargs -0 -r grep -lE "$SECRET_CONTENT" 2>/dev/null \
    | while IFS= read -r hit; do finding "content in ${hit}"; done
  FINDINGS=$((FINDINGS + content_hits))
else
  ok "  no secret-looking content in tracked files"
fi

# --- 3. Risky untracked files ------------------------------------------------
# A private file in the working tree is harmless until someone runs `git add .`.
# Reported, never fatal.

if [ "$SCAN_ALL" = "yes" ]; then
  info "3. Untracked files matching a forbidden pattern"
  untracked_hits=0
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    if printf '%s' "$path" | grep -qE "$FORBIDDEN_PATHS"; then
      is_allowed_template "$path" && continue
      warn "  untracked: ${path}"
      untracked_hits=$((untracked_hits + 1))
    fi
  done < <(git -C "$ROOT" ls-files --others --exclude-standard)
  [ "$untracked_hits" -eq 0 ] && ok "  nothing risky is untracked"
fi

# --- 4. History --------------------------------------------------------------
# Answers a different question — "was something ever committed" — and is slow,
# so it runs only on request.

if [ "$SCAN_HISTORY" = "yes" ]; then
  info "4. Committed history"
  added="$(git -C "$ROOT" log --all --pretty=format: --name-only --diff-filter=A 2>/dev/null | sort -u)"
  history_hits=0
  for pattern in '(^|/)\.env$' '\.pem$' '\.key$' '(^|/)CLAUDE\.md$' '(^|/)\.claude/'; do
    if printf '%s\n' "$added" | grep -qE "$pattern"; then
      warn "  history added a path matching /${pattern}/"
      history_hits=$((history_hits + 1))
    fi
  done
  if [ "$history_hits" -eq 0 ]; then
    ok "  no forbidden paths were ever added"
  else
    warn ""
    warn "  A file removed from the tip is still in history. If it held a real"
    warn "  secret, rotate the secret — rewriting history does not un-leak it."
  fi
fi

# --- Verdict -----------------------------------------------------------------

log ""
if [ "$FINDINGS" -gt 0 ]; then
  warn "${FINDINGS} problem(s) found. Do not push until they are resolved."
  exit 1
fi
ok "No private or credential material is about to be committed."
