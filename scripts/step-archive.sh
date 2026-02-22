#!/usr/bin/env bash
# chmod +x step-archive.sh
set -euo pipefail

CHANGES_DIR=".step/changes"
ARCHIVE_DIR=".step/archive"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
CORE_SCRIPT="${SCRIPT_DIR}/step-core.js"
STATE_FILE=".step/state.json"
TODAY="$(date +%F)"

task_status_is() {
  local task_file="$1"
  local expected="$2"
  node "$CORE_SCRIPT" task status --file "$task_file" --expected "$expected" >/dev/null 2>&1
}

print_usage() {
  cat <<'USAGE'
Usage:
  step-archive.sh [change-name1] [change-name2] ...
  step-archive.sh --all
USAGE
}

ensure_dirs() {
  mkdir -p "$ARCHIVE_DIR"
}

list_changes() {
  if [ -d "$CHANGES_DIR" ]; then
    for dir in "$CHANGES_DIR"/*; do
      [ -d "$dir" ] || continue
      basename "$dir"
    done
  fi
}

change_exists() {
  local name="$1"
  [ -d "$CHANGES_DIR/$name" ]
}

change_all_tasks_done() {
  local name="$1"
  local tasks_dir="$CHANGES_DIR/$name/tasks"

  if [ ! -d "$tasks_dir" ]; then
    return 1
  fi

  local found=0
  local task_file=""
  for task_file in "$tasks_dir"/*.md; do
    [ -f "$task_file" ] || continue
    found=1
    if ! task_status_is "$task_file" "done"; then
      return 1
    fi
    local task_slug
    task_slug="$(basename "$task_file" .md)"
    if ! node "$CORE_SCRIPT" task ready --task "$task_slug" --change "$name" >/dev/null 2>&1; then
      return 1
    fi
  done

  [ "$found" -eq 1 ]
}

next_archive_path() {
  local name="$1"
  local base="$ARCHIVE_DIR/${TODAY}-${name}"
  local target="$base"
  local n=1

  while [ -e "$target" ]; do
    target="${base}-${n}"
    n=$((n + 1))
  done

  printf "%s" "$target"
}

reset_state_if_current_change_archived() {
  local archived_name="$1"

  if [ ! -f "$STATE_FILE" ]; then
    return 0
  fi

  local current_change=""
  current_change=$(node "$CORE_SCRIPT" state get --file "$STATE_FILE" --path current_change 2>/dev/null || true)

  if [ "$current_change" = "$archived_name" ]; then
    node "$CORE_SCRIPT" state set --file "$STATE_FILE" --path current_change --value ""
    node "$CORE_SCRIPT" state set --file "$STATE_FILE" --path tasks.current --value null
  fi
}

archive_change() {
  local name="$1"

  if ! change_exists "$name"; then
    printf "  ⚠️  %s (not found, skipped)\n" "$name"
    return 2
  fi

  if ! change_all_tasks_done "$name"; then
    printf "  ⏭️ %s (tasks not all done, skipped)\n" "$name"
    return 3
  fi

  local source="$CHANGES_DIR/$name"
  local target
  target=$(next_archive_path "$name")

  mv "$source" "$target"
  reset_state_if_current_change_archived "$name"
  printf "  ✅ %s → %s\n" "$name" "$target"
  return 0
}

main() {
  if [ "$#" -eq 0 ]; then
    print_usage
    exit 1
  fi

  printf "📦 Archiving completed changes...\n"
  ensure_dirs

  local archived=0
  local skipped=0

  if [ "$1" = "--all" ]; then
    local names=""
    names=$(list_changes)
    if [ -z "$names" ]; then
      printf "📊 Archived: 0 change(s)\n"
      return 0
    fi

    local name=""
    for name in $names; do
      if archive_change "$name"; then
        archived=$((archived + 1))
      else
        skipped=$((skipped + 1))
      fi
    done

    printf "📊 Archived: %s change(s)\n" "$archived"
    if [ "$skipped" -gt 0 ]; then
      printf "📊 Skipped: %s change(s)\n" "$skipped"
    fi
    return 0
  fi

  local name=""
  for name in "$@"; do
    if archive_change "$name"; then
      archived=$((archived + 1))
    else
      skipped=$((skipped + 1))
    fi
  done

  printf "📊 Archived: %s change(s)\n" "$archived"
  if [ "$skipped" -gt 0 ]; then
    printf "📊 Skipped: %s change(s)\n" "$skipped"
  fi
}

main "$@"
