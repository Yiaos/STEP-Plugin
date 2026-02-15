#!/usr/bin/env bash
# chmod +x scripts/step-archive.sh
set -euo pipefail

TASKS_DIR=".step/tasks"
ARCHIVE_DIR=".step/archive"
TODAY="$(date +%F)"

print_usage() {
  cat <<'USAGE'
Usage:
  ./scripts/step-archive.sh [slug1] [slug2] ...
  ./scripts/step-archive.sh --all
USAGE
}

ensure_dirs() {
  mkdir -p "$ARCHIVE_DIR"
}

is_done() {
  local file="$1"
  if grep -q "^status:[[:space:]]*done" "$file"; then
    return 0
  fi
  return 1
}

archive_file() {
  local file="$1"
  local slug="$2"
  local dest="$ARCHIVE_DIR/${TODAY}-${slug}.yaml"
  mv "$file" "$dest"
  printf "  ✅ %s → %s\n" "$slug" "$dest"
}

list_task_files() {
  if [ -d "$TASKS_DIR" ]; then
    ls "$TASKS_DIR"/*.yaml 2>/dev/null || true
  fi
}

slug_from_path() {
  local file="$1"
  local base
  base="$(basename "$file")"
  printf "%s" "${base%.yaml}"
}

main() {
  if [ "$#" -eq 0 ]; then
    print_usage
    exit 1
  fi

  printf "📦 Archiving completed tasks...\n"
  ensure_dirs

  local archived=0
  local skipped=0

  if [ "$1" = "--all" ]; then
    local files
    files=$(list_task_files)
    if [ -z "$files" ]; then
      printf "📊 Archived: 0 task(s)\n"
      return 0
    fi

    for file in $files; do
      local slug
      slug="$(slug_from_path "$file")"
      if is_done "$file"; then
        archive_file "$file" "$slug"
        archived=$((archived + 1))
      else
        local status
        status=$(grep -E "^status:" "$file" | head -n 1 | sed 's/^status:[[:space:]]*//')
        if [ -z "$status" ]; then
          status="unknown"
        fi
        printf "  ⏭️ %s (status: %s, skipped)\n" "$slug" "$status"
        skipped=$((skipped + 1))
      fi
    done

    if [ "$archived" -eq 0 ]; then
      printf "📊 Archived: 0 task(s)\n"
      return 0
    fi

    printf "📊 Archived: %s task(s)\n" "$archived"
    return 0
  fi

  for slug in "$@"; do
    local file="$TASKS_DIR/${slug}.yaml"
    if [ ! -f "$file" ]; then
      printf "  ⚠️  %s (not found, skipped)\n" "$slug"
      skipped=$((skipped + 1))
      continue
    fi

    if is_done "$file"; then
      archive_file "$file" "$slug"
      archived=$((archived + 1))
    else
      local status
      status=$(grep -E "^status:" "$file" | head -n 1 | sed 's/^status:[[:space:]]*//')
      if [ -z "$status" ]; then
        status="unknown"
      fi
      printf "  ⏭️ %s (status: %s, skipped)\n" "$slug" "$status"
      skipped=$((skipped + 1))
    fi
  done

  if [ "$archived" -eq 0 ]; then
    printf "📊 Archived: 0 task(s)\n"
    return 0
  fi

  printf "📊 Archived: %s task(s)\n" "$archived"
}

main "$@"
