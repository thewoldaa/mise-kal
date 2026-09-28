#!/usr/bin/env bash
# =============================================================================
# Mise-Kal agent worktree harness — shared library
# =============================================================================
#
# WHAT THIS IS
#   The common code every harness script sources. It knows how to create an
#   isolated git worktree per sub-agent, claim a task, allocate a collision-free
#   port, record a wave, and clean up again.
#
# THE ONE INVARIANT THAT MATTERS
#   Two agents must never be able to touch each other's working tree. Every
#   agent gets its own directory under .harness/worktrees/, its own branch, its
#   own port block, and its own scratch directory. Nothing is shared except this
#   repository's git object store, which git already makes safe for concurrent
#   use. If you find yourself adding a shared file that two agents write to, you
#   have broken the harness — put it in the agent's own scratch instead.
#
# WHY NO flock
#   Git Bash on Windows ships without `flock`, so a lock built on it works on
#   the developer's Linux box and silently fails on Windows. Locks here are
#   therefore built from `mkdir`, which is atomic on every filesystem git runs
#   on, including NTFS over Git Bash.
#
# WHY NO GNU-only FLAGS
#   The harness has to run in Git Bash (MINGW64), on macOS, and on Linux. GNU
#   `timeout`, `flock`, `realpath -m` and `date +%s%N` are all absent or
#   different somewhere in that set, so none of them are used. Where a portable
#   equivalent is needed it is implemented in this file.
#
# Source it, do not execute it:
#   . "$(dirname "$0")/lib.sh"

# --- Strict mode -------------------------------------------------------------
# `pipefail` matters here: several helpers pipe into `tail`/`grep`, and without
# it a failure in the first command of a pipe is swallowed.
set -euo pipefail

# --- Paths -------------------------------------------------------------------
# HARNESS_SCRIPTS_DIR is the directory holding this file. Everything else is
# derived from it so the harness works from any checkout, in any worktree, at
# any depth, on any OS.
HARNESS_SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARNESS_DIR="$(cd "${HARNESS_SCRIPTS_DIR}/.." && pwd)"
# ROOT is the working tree the harness lives in. When a script is run from a
# worktree, ROOT is that worktree — which is what we want for per-agent checks.
ROOT="$(cd "${HARNESS_DIR}/.." && pwd)"

WORKTREES_DIR="${HARNESS_DIR}/worktrees"
TASKS_DIR="${HARNESS_DIR}/tasks"
WAVES_DIR="${HARNESS_DIR}/waves"
LOCKS_DIR="${HARNESS_DIR}/locks"
LOGS_DIR="${HARNESS_DIR}/logs"
CACHE_DIR="${HARNESS_DIR}/cache"
CONFIG_FILE="${HARNESS_DIR}/harness.conf"

# --- Colours -----------------------------------------------------------------
# Only when stdout is a terminal, so redirected logs stay readable.
if [ -t 1 ]; then
  C_RESET=$'\033[0m'; C_RED=$'\033[31m'; C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'; C_BLUE=$'\033[34m'; C_DIM=$'\033[2m'; C_BOLD=$'\033[1m'
else
  C_RESET=''; C_RED=''; C_GREEN=''; C_YELLOW=''; C_BLUE=''; C_DIM=''; C_BOLD=''
fi

log()  { printf '%s\n' "$*"; }
info() { printf '%s%s%s\n' "${C_BLUE}" "$*" "${C_RESET}"; }
ok()   { printf '%s%s%s\n' "${C_GREEN}" "$*" "${C_RESET}"; }
warn() { printf '%s%s%s\n' "${C_YELLOW}" "$*" "${C_RESET}" >&2; }
die()  { printf '%s%s%s\n' "${C_RED}" "$*" "${C_RESET}" >&2; exit 1; }
dim()  { printf '%s%s%s\n' "${C_DIM}" "$*" "${C_RESET}"; }

# --- Configuration -----------------------------------------------------------
# harness.conf is git-ignored: it is machine-local tuning, not project policy.
# Defaults are chosen so the harness works with no config file at all.
harness_conf() {
  local key="$1" fallback="$2"
  if [ -f "$CONFIG_FILE" ]; then
    # `|| true` because grep exits 1 on no match, which under `set -e` would
    # abort the caller for a missing optional key.
    local line
    line="$(grep -E "^${key}=" "$CONFIG_FILE" 2>/dev/null | tail -1 || true)"
    if [ -n "$line" ]; then
      printf '%s' "${line#*=}"
      return 0
    fi
  fi
  printf '%s' "$fallback"
}

PORT_BASE="$(harness_conf PORT_BASE 8200)"
PORT_BLOCK_SIZE="$(harness_conf PORT_BLOCK_SIZE 10)"
AGENT_SLOTS="$(harness_conf AGENT_SLOTS 16)"

# --- Small portable helpers --------------------------------------------------

# Slugify: lowercase, non-alphanumerics to single dashes, trimmed.
# Used for agent and task names so they are always safe as directory names,
# git branch components and Windows paths.
slugify() {
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -e 's/[^a-z0-9]\+/-/g' -e 's/^-//' -e 's/-$//'
}

# Validate a slug came out non-empty and not absurd. An empty agent name would
# resolve to the worktrees directory itself, and `rm -rf` on that is the kind of
# accident this check exists to prevent.
require_slug() {
  local what="$1" value="$2"
  [ -n "$value" ] || die "Invalid ${what}: empty after slugifying."
  case "$value" in
    */*|*\\*|.|..) die "Invalid ${what} '${value}': must not contain path separators." ;;
  esac
  [ "${#value}" -le 64 ] || die "Invalid ${what}: longer than 64 characters."
  printf '%s' "$value"
}

# Run a command with a timeout, portably.
# GNU `timeout` is not present in Git Bash, so this polls instead. It is used
# only for waiting on servers and `git` operations, never for anything whose
# exact timing matters.
run_with_timeout() {
  local seconds="$1"; shift
  "$@" &
  local cmd_pid=$!
  local waited=0
  while kill -0 "$cmd_pid" 2>/dev/null; do
    if [ "$waited" -ge "$seconds" ]; then
      kill -TERM "$cmd_pid" 2>/dev/null || true
      wait "$cmd_pid" 2>/dev/null || true
      return 124
    fi
    sleep 1
    waited=$((waited + 1))
  done
  wait "$cmd_pid"
}

# Wait for an HTTP endpoint to answer. Used to know a PocketBase instance is up
# before a test suite talks to it, instead of sleeping a guessed number of
# seconds and hoping.
wait_for_http() {
  local url="$1" attempts="${2:-60}"
  local i=0
  while [ "$i" -lt "$attempts" ]; do
    if curl -sf "$url" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.25
    i=$((i + 1))
  done
  return 1
}

# Is a TCP port free on loopback? Implemented with bash's /dev/tcp so it needs
# no netstat/ss, which differ between MINGW, macOS and Linux.
port_is_free() {
  local port="$1"
  ! (exec 3<>"/dev/tcp/127.0.0.1/${port}") 2>/dev/null
}

# Find the first free port at or after PORT_BASE, honouring the slot reservation
# so two concurrent agents cannot be handed the same one.
find_free_port() {
  local port
  for port in $(seq "$PORT_BASE" $((PORT_BASE + 200))); do
    if port_is_free "$port" && ! port_is_reserved "$port"; then
      printf '%s' "$port"
      return 0
    fi
  done
  die "No free port found in ${PORT_BASE}..$((PORT_BASE + 200))."
}

# --- Agent identity and slots ------------------------------------------------

# The agent name. Set AGENT_NAME explicitly to impersonate/attribute, otherwise
# fall back to the login name. Every worktree, branch, port block and scratch
# directory is keyed off this, so it must be stable for the life of a task.
agent_name() {
  local name="${AGENT_NAME:-${USER:-$(whoami 2>/dev/null || echo unknown)}}"
  slugify "$name"
}

# Deterministic slot in 0..AGENT_SLOTS-1, derived from the agent name.
# Deterministic on purpose: an agent that crashes and reconnects gets the same
# port block back, so a half-finished test run is not orphaned on a port nobody
# remembers. Collisions between two different names are possible and handled by
# the reservation check in find_free_port, not by hoping they do not happen.
agent_slot() {
  local name="$1" sum=0 i ch
  for ((i = 0; i < ${#name}; i++)); do
    ch=$(printf '%d' "'${name:$i:1}" 2>/dev/null || echo 0)
    sum=$(( (sum * 31 + ch) % AGENT_SLOTS ))
  done
  printf '%s' "$sum"
}

agent_branch() {
  local name="$1" task="${2:-}"
  if [ -n "$task" ]; then
    printf 'agent/%s/%s' "$name" "$task"
  else
    printf 'agent/%s' "$name"
  fi
}

agent_worktree() {
  printf '%s/%s' "$WORKTREES_DIR" "$1"
}

# Per-agent scratch. Never inside the worktree: `git clean -xdf` during a reset
# would delete it, and a scratch file that vanishes mid-run is worse than none.
# Lives under .harness/logs/ which is git-ignored.
agent_scratch() {
  local dir="${LOGS_DIR}/$1/scratch"
  mkdir -p "$dir"
  printf '%s' "$dir"
}

# --- Locking (mkdir-based, flock-free) ---------------------------------------
# mkdir is atomic on POSIX and on NTFS, and needs no external binary, which is
# exactly what Git Bash lacks. A lock older than LOCK_STALE_SECONDS is assumed
# to belong to a process that died without cleaning up, and is stolen. That
# window is deliberately long: stealing a live lock causes two agents to run the
# same suite against the same port, which is far more confusing than waiting.

LOCK_STALE_SECONDS=3600

acquire_lock() {
  local name="$1" timeout="${2:-30}"
  local lock_dir="${LOCKS_DIR}/${name}.lock"
  mkdir -p "$LOCKS_DIR"
  local waited=0
  while true; do
    if mkdir "$lock_dir" 2>/dev/null; then
      printf '%s\n' "$$" > "${lock_dir}/pid"
      date -u '+%Y-%m-%dT%H:%M:%SZ' > "${lock_dir}/acquired_at" 2>/dev/null || true
      return 0
    fi
    # Steal if stale.
    local age
    age="$(lock_age_seconds "$lock_dir")"
    if [ "$age" -gt "$LOCK_STALE_SECONDS" ]; then
      warn "Stealing stale lock '${name}' (${age}s old)."
      rm -rf "$lock_dir"
      continue
    fi
    if [ "$waited" -ge "$timeout" ]; then
      die "Timed out after ${timeout}s waiting for lock '${name}' held by pid $(cat "${lock_dir}/pid" 2>/dev/null || echo '?')."
    fi
    sleep 1
    waited=$((waited + 1))
  done
}

release_lock() {
  local name="$1"
  rm -rf "${LOCKS_DIR}/${name}.lock" 2>/dev/null || true
}

# Age of a lock directory in seconds, without GNU `stat -c` or `date +%s%N`.
# Falls back to 0 (i.e. "not stale") when the age cannot be determined, so an
# unreadable timestamp never causes a live lock to be stolen.
lock_age_seconds() {
  local lock_dir="$1" now then
  now="$(date +%s 2>/dev/null || echo 0)"
  if [ -f "${lock_dir}/acquired_at" ]; then
    then="$(date -u -d "$(cat "${lock_dir}/acquired_at" 2>/dev/null)" +%s 2>/dev/null || echo 0)"
  else
    then=0
  fi
  if [ "$now" -gt 0 ] && [ "$then" -gt 0 ] && [ "$now" -ge "$then" ]; then
    printf '%s' "$((now - then))"
  else
    printf '0'
  fi
}

# --- Port reservation --------------------------------------------------------
# A reservation is a directory under locks/. Directories are used rather than
# files because mkdir is the atomic primitive available here.

reserve_port() {
  local port="$1" agent="$2"
  mkdir -p "${LOCKS_DIR}/ports"
  local dir="${LOCKS_DIR}/ports/${port}"
  if mkdir "$dir" 2>/dev/null; then
    printf '%s\n' "$agent" > "${dir}/agent"
    printf '%s\n' "$(date +%s 2>/dev/null || echo 0)" > "${dir}/at"
    return 0
  fi
  return 1
}

release_port() {
  rm -rf "${LOCKS_DIR}/ports/$1" 2>/dev/null || true
}

port_is_reserved() {
  [ -d "${LOCKS_DIR}/ports/$1" ]
}

# Reserve a whole block for one agent, so a suite that starts several servers
# (PocketBase plus a fake printer, say) cannot collide with a sibling agent.
#
# Idempotent: a port already reserved by *this* agent is reclaimed rather than
# treated as a conflict. Without that, re-running a suite after a failure would
# see its own previous reservation as a collision and fall back to scattered
# ports, which is exactly the fragmentation the block exists to prevent.
reserve_port_block() {
  local agent="$1"
  local slot block_start port reserved holder
  slot="$(agent_slot "$agent")"
  block_start=$((PORT_BASE + slot * PORT_BLOCK_SIZE))
  reserved=""
  for port in $(seq "$block_start" $((block_start + PORT_BLOCK_SIZE - 1))); do
    if reserve_port "$port" "$agent"; then
      reserved="${reserved}${port} "
    else
      holder="$(cat "${LOCKS_DIR}/ports/${port}/agent" 2>/dev/null || echo '')"
      if [ "$holder" = "$agent" ]; then
        reserved="${reserved}${port} "
      fi
    fi
  done
  if [ -z "$reserved" ]; then
    # Whole block genuinely held by another agent that hashed to the same slot.
    # Fall back to individual free ports so this agent still runs, just without
    # the tidy contiguous block.
    warn "Port block for '${agent}' is taken by another agent; falling back to individual ports."
    for port in $(seq "$PORT_BASE" $((PORT_BASE + 200))); do
      if reserve_port "$port" "$agent"; then
        reserved="${reserved}${port} "
        break
      fi
    done
  fi
  printf '%s' "$reserved"
}

release_port_block() {
  local agent="$1" dir
  for dir in "${LOCKS_DIR}/ports"/*; do
    [ -d "$dir" ] || continue
    if [ "$(cat "${dir}/agent" 2>/dev/null || echo '')" = "$agent" ]; then
      rm -rf "$dir"
    fi
  done
}

# --- Git identity ------------------------------------------------------------
# A missing user.name/user.email does not stop you from editing files, so it
# goes unnoticed until the first commit or merge — at which point git fails with
# "Committer identity unknown" and, in a merge, that failure is easy to
# misread as a conflict. Checking for it up front turns a confusing failure into
# a one-line instruction.
require_git_identity() {
  local name email
  name="$(git -C "$ROOT" config user.name 2>/dev/null || echo '')"
  email="$(git -C "$ROOT" config user.email 2>/dev/null || echo '')"
  if [ -z "$name" ] || [ -z "$email" ]; then
    die "Git identity is not configured for this repository, so commits and
     merges will fail. Set it once, here:
       git -C \"${ROOT}\" config user.name \"Your Name\"
       git -C \"${ROOT}\" config user.email \"you@example.com\""
  fi
}

# --- Worktree operations -----------------------------------------------------

worktree_exists() {
  local agent="$1"
  [ -d "$(agent_worktree "$agent")" ]
}

# Which worktree has this branch checked out, if any? Used to point a conflict
# at the agent who can actually resolve it, instead of at a placeholder path.
find_worktree_for_branch() {
  local want="$1"
  local dir branch
  [ -d "$WORKTREES_DIR" ] || return 0
  for dir in "$WORKTREES_DIR"/*; do
    [ -d "$dir" ] || continue
    branch="$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '')"
    if [ "$branch" = "$want" ]; then
      printf '%s' "$dir"
      return 0
    fi
  done
}

# Create (or reuse) an isolated worktree for an agent.
#
# Reuse is deliberate: a wave that runs twice, or an agent resuming after a
# crash, must land in the same tree with its work intact. Re-creating would
# discard uncommitted work, which is the single most expensive mistake this
# harness could make.
create_worktree() {
  local agent="$1" task="${2:-}" base="${3:-}"
  local dir branch
  dir="$(agent_worktree "$agent")"
  branch="$(agent_branch "$agent" "$task")"

  mkdir -p "$WORKTREES_DIR"

  # A real worktree contains a `.git` *file* pointing at the parent repository's
  # worktree metadata. A plain directory does not. This distinction matters more
  # than it looks: if a directory exists without that file, it is not a
  # worktree, and any git command run inside it silently operates on the parent
  # repository instead — so an agent would edit main's files believing it was
  # isolated, and its commits would land on the wrong branch.
  if [ -d "$dir" ] && [ ! -e "${dir}/.git" ]; then
    die "Directory '${dir}' exists but is not a git worktree (no .git file).
     This usually means a previous 'git worktree add' failed after the
     directory was created, or something else created the path.
     Refusing to continue, because git commands run there would silently
     operate on '${ROOT}' instead.
     Inspect it, then remove it:  rm -rf \"${dir}\""
  fi

  if [ -d "$dir" ]; then
    local current
    current="$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '')"
    if [ "$current" = "$branch" ]; then
      ok "Worktree already exists for '${agent}' on '${branch}' (reusing)."
      printf '%s' "$dir"
      return 0
    fi
    die "Worktree '${dir}' exists on branch '${current}', expected '${branch}'.
     Refusing to touch it. Inspect it, then either reuse it or remove it with:
       .harness/scripts/worktree.sh remove ${agent}"
  fi

  if [ -z "$base" ]; then
    base="$(git -C "$ROOT" rev-parse HEAD)"
  fi

  # A branch that already exists (previous wave, same name) is reused rather
  # than reset, for the same reason as above: never discard work silently.
  if git -C "$ROOT" show-ref --verify --quiet "refs/heads/${branch}"; then
    warn "Branch '${branch}' already exists; attaching a worktree to it."
    git -C "$ROOT" worktree add "$dir" "$branch" >/dev/null
  else
    git -C "$ROOT" worktree add -b "$branch" "$dir" "$base" >/dev/null
  fi

  # Verify the worktree is real before reporting success. `git worktree add` can
  # fail in ways that still leave a directory behind, and a create that reports
  # success while producing a non-worktree is the most dangerous failure this
  # harness can have: the agent believes it is isolated and it is not.
  if [ ! -e "${dir}/.git" ]; then
    die "git worktree add appeared to succeed but '${dir}/.git' is missing.
     The directory is not an isolated worktree. Do not work in it.
     Investigate, then remove it:  rm -rf \"${dir}\""
  fi
  local resolved
  resolved="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null || echo '')"
  if [ "$resolved" != "$dir" ] && [ "$(cd "$resolved" 2>/dev/null && pwd -P)" != "$(cd "$dir" && pwd -P)" ]; then
    die "Worktree at '${dir}' resolves to '${resolved}'. Git commands there would
     operate on the wrong repository. Refusing to continue."
  fi

  ok "Created worktree '${agent}' at ${dir} on branch '${branch}'."
  printf '%s' "$dir"
}

remove_worktree() {
  local agent="$1" force="${2:-no}"
  local dir
  dir="$(agent_worktree "$agent")"

  if [ ! -d "$dir" ]; then
    warn "No worktree for '${agent}'."
    return 0
  fi

  # Refuse to destroy uncommitted work unless explicitly forced. Losing an
  # agent's in-progress changes to a stray `remove` is the failure this whole
  # harness exists to prevent, so the default is to stop and tell the operator.
  if [ "$force" != "force" ]; then
    local dirty
    dirty="$(git -C "$dir" status --porcelain 2>/dev/null | head -5 || true)"
    if [ -n "$dirty" ]; then
      die "Worktree '${agent}' has uncommitted changes:
$(printf '%s\n' "$dirty")
     Commit them, or remove with: .harness/scripts/worktree.sh remove ${agent} --force"
    fi
    local branch
    branch="$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '')"
    local ahead
    ahead="$(git -C "$dir" rev-list --count "origin/main..${branch}" 2>/dev/null || echo 0)"
    if [ "$ahead" -gt 0 ] 2>/dev/null; then
      warn "Branch '${branch}' is ${ahead} commit(s) ahead of origin/main."
      warn "Removing the worktree keeps the branch; merge it or delete it explicitly."
    fi
  fi

  git -C "$ROOT" worktree remove --force "$dir" 2>/dev/null || rm -rf "$dir"
  git -C "$ROOT" worktree prune >/dev/null 2>&1 || true
  release_port_block "$agent"
  ok "Removed worktree for '${agent}'."
}

# Is the worktree clean? Used as a pre-merge gate: merging a branch that still
# has uncommitted edits means the agent reported work it never recorded.
worktree_is_clean() {
  local dir="$1"
  [ -z "$(git -C "$dir" status --porcelain 2>/dev/null | head -1 || true)" ]
}

worktree_status() {
  local agent="$1" dir branch head dirty ahead behind
  dir="$(agent_worktree "$agent")"
  if [ ! -d "$dir" ]; then
    printf '%-18s %s\n' "$agent" "absent"
    return 0
  fi
  branch="$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')"
  head="$(git -C "$dir" rev-parse --short HEAD 2>/dev/null || echo '?')"
  if worktree_is_clean "$dir"; then dirty="clean"; else dirty="dirty"; fi
  ahead="$(git -C "$dir" rev-list --count "origin/main..${branch}" 2>/dev/null || echo '?')"
  behind="$(git -C "$dir" rev-list --count "${branch}..origin/main" 2>/dev/null || echo '?')"
  printf '%-18s %-34s %-8s %-6s +%s/-%s\n' "$agent" "$branch" "$head" "$dirty" "$ahead" "$behind"
}

# --- Task operations ---------------------------------------------------------
# Tasks are plain markdown with YAML-ish front matter, deliberately: they must
# be reviewable in a pull request and editable by hand without a schema tool.

task_file() {
  printf '%s/%s.md' "$TASKS_DIR" "$1"
}

task_field() {
  local id="$1"
  local field="$2"
  local file
  file="$(task_file "$id")"
  [ -f "$file" ] || return 1
  # Front matter only: stop at the closing --- so a field name mentioned in the
  # body prose is never mistaken for the value.
  awk -v want="$field" '
    NR == 1 && $0 ~ /^---/ { in_fm = 1; next }
    in_fm && $0 ~ /^---/ { exit }
    in_fm && index($0, want ":") == 1 { sub(/^[^:]*:[ ]*/, ""); print; exit }
  ' "$file"
}

task_exists() { [ -f "$(task_file "$1")" ]; }

list_tasks() {
  local file id status owner
  [ -d "$TASKS_DIR" ] || return 0
  printf '%-22s %-12s %-12s %s\n' "TASK" "STATUS" "OWNER" "TITLE"
  for file in "$TASKS_DIR"/*.md; do
    [ -f "$file" ] || continue
    id="$(basename "$file" .md)"
    status="$(task_field "$id" status || echo '?')"
    owner="$(task_field "$id" owner || echo '-')"
    printf '%-22s %-12s %-12s %s\n' "$id" "$status" "${owner:--}" "$(task_field "$id" title || echo '')"
  done
}

# Claim a task for an agent. The claim is recorded in the task file so it is
# visible in review, and a task already claimed by a *different* agent is
# refused rather than silently stolen.
claim_task() {
  local id="$1"
  local agent="$2"
  local file status owner
  file="$(task_file "$id")"
  [ -f "$file" ] || die "No such task: ${id} (looked for ${file})"

  status="$(task_field "$id" status || echo '')"
  owner="$(task_field "$id" owner || echo '')"

  if [ -n "$owner" ] && [ "$owner" != "-" ] && [ "$owner" != "$agent" ]; then
    die "Task '${id}' is already claimed by '${owner}'. Two agents on one task is
     how duplicate work and conflicting commits happen. Pick another task."
  fi
  if [ "$status" = "done" ]; then
    warn "Task '${id}' is marked done. Re-claiming will reopen it."
  fi

  set_task_field "$id" owner "$agent"
  set_task_field "$id" status "claimed"
  ok "Task '${id}' claimed by '${agent}'."
}

set_task_field() {
  local id="$1" field="$2" value="$3" file tmp
  file="$(task_file "$id")"
  [ -f "$file" ] || die "No such task: ${id}"
  tmp="${file}.tmp.$$"
  # Only rewrite a line inside the front matter block.
  awk -v want="$field" -v val="$value" '
    BEGIN { in_fm = 0; done = 0 }
    NR == 1 && $0 ~ /^---/ { in_fm = 1; print; next }
    in_fm && $0 ~ /^---/ && !done {
      if (!found) print want ": " val
      in_fm = 0; done = 1; print; next
    }
    in_fm && !done && index($0, want ":") == 1 {
      print want ": " val; found = 1; next
    }
    { print }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
}

# --- Wave operations ---------------------------------------------------------
# A wave is a batch of agents working in parallel on tasks that do not depend on
# each other, followed by a controlled integration step.

wave_dir() { printf '%s/%s' "$WAVES_DIR" "$1"; }

wave_create() {
  local id="$1" description="${2:-}" dir
  dir="$(wave_dir "$id")"
  mkdir -p "$dir"
  printf '%s\n' "$description" > "${dir}/DESCRIPTION.txt"
  date -u '+%Y-%m-%dT%H:%M:%SZ' > "${dir}/created_at" 2>/dev/null || date > "${dir}/created_at"
  # AGENTS.txt is the manifest: one agent name per line, added as work starts.
  [ -f "${dir}/AGENTS.txt" ] || : > "${dir}/AGENTS.txt"
  [ -f "${dir}/STATUS.txt" ] || printf 'open\n' > "${dir}/STATUS.txt"
  ok "Wave '${id}' created."
}

wave_add_agent() {
  local wave="$1" agent="$2" dir
  dir="$(wave_dir "$wave")"
  [ -d "$dir" ] || die "No such wave: ${wave}"
  grep -qxF "$agent" "${dir}/AGENTS.txt" 2>/dev/null || printf '%s\n' "$agent" >> "${dir}/AGENTS.txt"
}

wave_agents() {
  local wave="$1" dir
  dir="$(wave_dir "$wave")"
  [ -f "${dir}/AGENTS.txt" ] && cat "${dir}/AGENTS.txt" || true
}

# --- Environment preparation -------------------------------------------------
# PocketBase and jq are fetched rather than vendored, matching upstream's
# approach. They land in .harness/cache/, which is git-ignored, so a fresh clone
# stays small and no binary ever enters the repository.

# NOTE: each `local` is on its own line throughout this file on purpose.
# In bash, `local a="$1" b="$a"` expands *every* word before any assignment
# happens, so `$a` is still unset when `b` is computed — and under `set -u` that
# aborts the function with "unbound variable". Splitting the declarations is the
# only correct form.
tool_cache() {
  local tool="$1"
  local dir="${CACHE_DIR}/${tool}"
  mkdir -p "$dir"
  printf '%s' "$dir"
}

pocketbase_path() {
  local dir
  dir="$(tool_cache pocketbase)"
  if [ -f "${dir}/pocketbase.exe" ]; then printf '%s' "${dir}/pocketbase.exe"
  elif [ -f "${dir}/pocketbase" ]; then printf '%s' "${dir}/pocketbase"
  else printf '%s' "${dir}/pocketbase"; fi
}

jq_path() {
  local dir
  dir="$(tool_cache jq)"
  if [ -f "${dir}/jq.exe" ]; then printf '%s' "${dir}/jq.exe"
  else printf '%s' "${dir}/jq"; fi
}

# Put cached tools on PATH so the upstream test scripts, which call bare `jq`,
# work unmodified. This is a deliberate choice: Mise-Kal's Phase 1 goal is to
# stabilise upstream behaviour, and rewriting five suites before they have ever
# been run here would make any failure impossible to attribute.
harness_export_path() {
  local pb_dir jq_dir
  pb_dir="$(tool_cache pocketbase)"
  jq_dir="$(tool_cache jq)"
  export PATH="${jq_dir}:${pb_dir}:${PATH}"
}

# --- Reporting ---------------------------------------------------------------
# Every agent ends by writing a report, so the orchestrator integrates from
# recorded facts rather than from a chat message that scrolled away.

write_report() {
  local agent="$1" task="$2" summary="$3" dir
  dir="${LOGS_DIR}/${agent}"
  mkdir -p "$dir"
  local file="${dir}/report-${task:-general}.md"
  {
    printf '# Agent report: %s / %s\n\n' "$agent" "${task:-general}"
    printf '- Generated: %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date)"
    printf '- Branch: %s\n' "$(git -C "$ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')"
    printf '- HEAD: %s\n\n' "$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo '?')"
    printf '## Summary\n\n%s\n\n' "$summary"
    printf '## Commits on this branch\n\n```\n'
    git -C "$ROOT" log --oneline "origin/main..HEAD" 2>/dev/null || true
    printf '```\n\n'
    printf '## Files changed\n\n```\n'
    git -C "$ROOT" diff --stat "origin/main...HEAD" 2>/dev/null || true
    printf '```\n'
  } > "$file"
  ok "Report written to ${file}"
}
