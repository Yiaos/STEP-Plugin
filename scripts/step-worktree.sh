#!/usr/bin/env bash
# STEP Protocol — Worktree workflow helper
set -euo pipefail

CONFIG_FILE=".step/config.yaml"
WT_ROOT_DEFAULT=".worktrees"

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/step-worktree.sh create <change-name>
  ./scripts/step-worktree.sh finalize <change-name> [--yes]

Commands:
  create    Create or reuse worktree for change branch
  finalize  Ask merge+archive, merge to base branch, resolve conflicts, cleanup
USAGE
}

require_git_repo() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
    echo "❌ Not in git repository"
    exit 1
  }
}

repo_root() {
  git rev-parse --show-toplevel
}

read_worktree_config() {
  local key="$1"
  local default_value="$2"

  if [ ! -f "$CONFIG_FILE" ]; then
    printf "%s" "$default_value"
    return
  fi

  local value
  value=$(awk -v k="$key" '
    BEGIN { in_wt=0 }
    /^worktree:[[:space:]]*$/ { in_wt=1; next }
    in_wt && /^[^[:space:]]/ { in_wt=0 }
    in_wt {
      if ($0 ~ "^[[:space:]]*" k ":[[:space:]]*") {
        line=$0
        sub("^[[:space:]]*" k ":[[:space:]]*", "", line)
        gsub(/"/, "", line)
        print line
        exit
      }
    }
  ' "$CONFIG_FILE")

  if [ -z "$value" ]; then
    printf "%s" "$default_value"
  else
    printf "%s" "$value"
  fi
}

worktree_enabled() {
  local enabled
  enabled=$(read_worktree_config "enabled" "false")
  [ "$enabled" = "true" ]
}

worktree_root_abs() {
  printf "%s/%s" "$(repo_root)" "$WT_ROOT_DEFAULT"
}

change_branch() {
  local change_name="$1"
  local prefix
  prefix=$(read_worktree_config "branch_prefix" "change/")
  printf "%s%s" "$prefix" "$change_name"
}

current_branch() {
  git rev-parse --abbrev-ref HEAD
}

remember_step_base_branch() {
  local feature_branch="$1"
  local base="$2"
  git config "branch.${feature_branch}.step-base" "$base"
}

step_base_branch() {
  local feature_branch="$1"
  local base
  base=$(git config --get "branch.${feature_branch}.step-base" || true)
  if [ -z "$base" ]; then
    base=$(current_branch)
  fi
  printf "%s" "$base"
}

choose_conflict_strategy() {
  local file_path="$1"
  local change_name="$2"

  if [ "$file_path" = ".step/state.yaml" ]; then
    printf "ours"
    return
  fi

  if [[ "$file_path" == .step/changes/"${change_name}"/* ]]; then
    printf "theirs"
    return
  fi

  printf "ours"
}

find_worktree_for_branch() {
  local branch="$1"
  local path=""
  local current_path=""
  local current_branch=""

  while IFS= read -r line; do
    case "$line" in
      worktree\ *) current_path="${line#worktree }" ;;
      branch\ *)
        current_branch="${line#branch refs/heads/}"
        if [ "$current_branch" = "$branch" ]; then
          path="$current_path"
          break
        fi
        ;;
    esac
  done < <(git worktree list --porcelain)

  printf "%s" "$path"
}

is_worktree_path() {
  local target_path="$1"
  local path=""

  while IFS= read -r line; do
    case "$line" in
      worktree\ *)
        path="${line#worktree }"
        if [ "$path" = "$target_path" ]; then
          return 0
        fi
        ;;
    esac
  done < <(git worktree list --porcelain)

  return 1
}

create_worktree() {
  local change_name="$1"

  if ! worktree_enabled; then
    echo "ℹ️ worktree.enabled=false，跳过 worktree 创建"
    return 0
  fi

  local wt_root
  wt_root=$(worktree_root_abs)
  local branch
  branch=$(change_branch "$change_name")
  local base
  base=$(current_branch)
  local wt_path="${wt_root}/${change_name}"

  mkdir -p "$wt_root"

  if [ -d "$wt_path" ]; then
    if ! is_worktree_path "$wt_path"; then
      echo "❌ Path exists but is not a git worktree: $wt_path"
      echo "   请手动清理后重试"
      return 1
    fi
    if [ -z "$(git config --get "branch.${branch}.step-base" || true)" ]; then
      remember_step_base_branch "$branch" "$base"
    fi
    echo "✅ Worktree exists: $wt_path"
    return 0
  fi

  if git show-ref --verify --quiet "refs/heads/${branch}"; then
    git worktree add "$wt_path" "$branch"
  else
    git worktree add -b "$branch" "$wt_path" "$base"
  fi

  remember_step_base_branch "$branch" "$base"

  echo "✅ Worktree created"
  echo "   change: $change_name"
  echo "   branch: $branch"
  echo "   path:   $wt_path"
}

archive_change_on_base_worktree() {
  local change_name="$1"
  local merge_wt="$2"

  if [ -x "$merge_wt/scripts/step-archive.sh" ]; then
    local out
    out=$(bash "$merge_wt/scripts/step-archive.sh" "$change_name" 2>&1 || true)
    printf "%s\n" "$out"
    if ! git -C "$merge_wt" diff --quiet -- .step; then
      git -C "$merge_wt" add .step
      if git -C "$merge_wt" commit -m "chore(step): archive ${change_name} after merge" >/dev/null 2>&1; then
        echo "✅ Archived change committed on base branch"
      else
        echo "⚠️ Archive commit failed on base branch"
        echo "   请检查 $merge_wt/.git 状态并手动提交 .step"
        return 1
      fi
    fi
  fi
}

merge_with_conflict_report() {
  local change_name="$1"
  local branch="$2"
  local base="$3"

  local merge_wt
  merge_wt=$(find_worktree_for_branch "$base")
  local temp_merge_wt=""

  if [ -z "$merge_wt" ]; then
    temp_merge_wt="$(worktree_root_abs)/_merge-${change_name}"
    mkdir -p "$(worktree_root_abs)"
    git worktree add "$temp_merge_wt" "$base"
    merge_wt="$temp_merge_wt"
  fi

  if git -C "$merge_wt" merge --no-ff "$branch" -m "merge(step): ${change_name}"; then
    echo "✅ Merged ${branch} -> ${base}"
  else
    local conflicts
    conflicts=$(git -C "$merge_wt" diff --name-only --diff-filter=U)
    if [ -z "$conflicts" ]; then
      echo "❌ Merge failed without conflict list"
      [ -n "$temp_merge_wt" ] && git worktree remove "$temp_merge_wt" --force || true
      exit 1
    fi

    echo "⚠️ Merge conflicts detected:"
    local conflict_file=""
    for conflict_file in $conflicts; do
      local strategy
      strategy=$(choose_conflict_strategy "$conflict_file" "$change_name")
      git -C "$merge_wt" checkout --"$strategy" -- "$conflict_file"
      git -C "$merge_wt" add "$conflict_file"
      echo "  - $conflict_file  => used '$strategy'"
    done

    git -C "$merge_wt" commit -m "merge(step): ${change_name} (auto-resolved conflicts)" >/dev/null 2>&1
    echo "✅ Conflicts resolved and merged"
  fi

  if ! archive_change_on_base_worktree "$change_name" "$merge_wt"; then
    echo "⚠️ 归档未完成，.step 可能存在未提交变更"
  fi

  if [ -n "$temp_merge_wt" ]; then
    git worktree remove "$temp_merge_wt" --force || true
  fi
}

cleanup_feature_worktree() {
  local branch="$1"
  local wt_path="$2"

  if [ -d "$wt_path" ]; then
    if [ "$(pwd)" = "$wt_path" ]; then
      echo "⚠️ 当前位于 feature worktree，跳过自动清理: $wt_path"
      echo "   请切换目录后手动执行: git worktree remove \"$wt_path\""
    else
      git worktree remove "$wt_path" --force || true
      echo "🧹 Worktree removed: $wt_path"
    fi
  fi

  git branch -d "$branch" >/dev/null 2>&1 || true
}

finalize_worktree() {
  local change_name="$1"
  local auto_yes="${2:-false}"

  if ! worktree_enabled; then
    echo "ℹ️ worktree.enabled=false，跳过合并/归档流程"
    return 0
  fi

  local branch
  branch=$(change_branch "$change_name")
  local base
  base=$(step_base_branch "$branch")
  local wt_path
  wt_path="$(worktree_root_abs)/${change_name}"

  local do_merge="false"
  if [ "$auto_yes" = "true" ]; then
    do_merge="true"
  else
    printf "✅ Commit 已完成。是否合并回 %s 并归档？[y/N] " "$base"
    read -r answer || true
    case "$answer" in
      y|Y|yes|YES) do_merge="true" ;;
      *) do_merge="false" ;;
    esac
  fi

  if [ "$do_merge" != "true" ]; then
    echo "ℹ️ 已跳过合并/归档"
    return 0
  fi

  merge_with_conflict_report "$change_name" "$branch" "$base"
  cleanup_feature_worktree "$branch" "$wt_path"
}

main() {
  require_git_repo

  local cmd="${1:-}"
  local change_name="${2:-}"
  local auto_yes="false"

  if [ "$#" -ge 3 ] && [ "$3" = "--yes" ]; then
    auto_yes="true"
  fi

  case "$cmd" in
    create)
      [ -n "$change_name" ] || { usage; exit 1; }
      create_worktree "$change_name"
      ;;
    finalize)
      [ -n "$change_name" ] || { usage; exit 1; }
      finalize_worktree "$change_name" "$auto_yes"
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
