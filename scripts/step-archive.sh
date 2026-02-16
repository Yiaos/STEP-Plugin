#!/usr/bin/env bash
# chmod +x scripts/step-archive.sh
set -euo pipefail

CHANGES_DIR=".step/changes"
ARCHIVE_DIR=".step/archive"
STATE_FILE=".step/state.yaml"
TODAY="$(date +%F)"

print_usage() {
  cat <<'USAGE'
Usage:
  ./scripts/step-archive.sh [change-name1] [change-name2] ...
  ./scripts/step-archive.sh --all
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
  for task_file in "$tasks_dir"/*.yaml; do
    [ -f "$task_file" ] || continue
    found=1
    if ! grep -q '^status:[[:space:]]*done' "$task_file"; then
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
  current_change=$(grep '^current_change:' "$STATE_FILE" 2>/dev/null | head -1 | sed 's/^current_change:[[:space:]]*//' | tr -d ' "' || true)

  if [ "$current_change" = "$archived_name" ]; then
    sed -i.bak 's/^current_change:.*/current_change: ""/' "$STATE_FILE"
    sed -i.bak 's/^\([[:space:]]*current:\).*/\1 null/' "$STATE_FILE"
    rm -f "$STATE_FILE.bak"
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
