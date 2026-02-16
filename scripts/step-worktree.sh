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
  finalize  Ask merge+archive, merge to base branch, resolve conflicts via LLM, cleanup
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

meta_dir() {
  printf ".step/worktrees"
}

meta_file() {
  local change_name="$1"
  printf "%s/%s.meta" "$(meta_dir)" "$change_name"
}

remember_step_meta() {
  local change_name="$1"
  local feature_branch="$2"
  local base="$3"
  local wt_path="$4"
  mkdir -p "$(meta_dir)"
  cat > "$(meta_file "$change_name")" <<EOF
change_name=$change_name
feature_branch=$feature_branch
base_branch=$base
worktree_path=$wt_path
EOF
}

read_meta_value() {
  local change_name="$1"
  local key="$2"
  local mf
  mf=$(meta_file "$change_name")
  if [ ! -f "$mf" ]; then
    printf ""
    return
  fi
  awk -F'=' -v k="$key" '$1==k {print $2; exit}' "$mf"
}

step_base_branch() {
  local change_name="$1"
  local base
  base=$(read_meta_value "$change_name" "base_branch")
  if [ -z "$base" ]; then
    base=$(current_branch)
  fi
  printf "%s" "$base"
}

step_feature_branch() {
  local change_name="$1"
  local fallback="$2"
  local feature
  feature=$(read_meta_value "$change_name" "feature_branch")
  if [ -z "$feature" ]; then
    feature="$fallback"
  fi
  printf "%s" "$feature"
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

  if [[ "$file_path" == .step/* ]]; then
    printf "ours"
    return
  fi

  printf "manual"
}

write_conflict_report() {
  local merge_wt="$1"
  local change_name="$2"
  local branch="$3"
  local base="$4"
  local resolver_log="$5"
  local resolver_summary_file="$6"
  shift 6
  local report_files=("$@")
  local report_path
  report_path="$(repo_root)/.step/conflict-report.md"
  mkdir -p "$(repo_root)/.step"
  {
    echo "# Conflict Report"
    echo ""
    echo "- change: $change_name"
    echo "- feature branch: $branch"
    echo "- base branch: $base"
    echo ""
    echo "## Conflict Files"
    echo "以下代码冲突已交由大模型解决："
    echo ""
    for f in "${report_files[@]}"; do
      echo "- $f"
    done
    echo ""
    echo "## Resolution Strategy"
    echo "- 保留双方有效改动，不允许静默丢失功能"
    echo "- .step 元数据按既定策略自动处理"
    echo ""
    if [ -f "$resolver_summary_file" ]; then
      echo "## LLM Resolution Summary"
      cat "$resolver_summary_file"
      echo ""
    fi
    if [ -f "$resolver_log" ]; then
      echo "## LLM Run Log (tail)"
      tail -n 80 "$resolver_log"
      echo ""
    fi
    echo "## User-facing Summary Requirement"
    echo "完成后必须向用户说明："
    echo "1. 哪些文件发生冲突"
    echo "2. 每个文件保留了哪边改动以及原因"
    echo "3. gate/scenario 的验证结果"
  } > "$report_path"
  echo "📄 冲突报告已生成: $report_path"
}

run_llm_conflict_resolution() {
  local merge_wt="$1"
  local change_name="$2"
  local branch="$3"
  local base="$4"
  local resolver_log="$5"
  local summary_file="$6"
  shift 6
  local conflict_files=("$@")

  mkdir -p "$merge_wt/.step"

  local prompt_file="$merge_wt/.step/conflict-resolution-prompt.md"
  {
    echo "你是 STEP 的冲突解决代理。请处理当前 git merge 冲突。"
    echo ""
    echo "约束："
    echo "1. 不能直接丢弃某一侧改动，必须尽量保留双方有效逻辑。"
    echo "2. 不允许保留冲突标记（<<<<<<< ======= >>>>>>>）。"
    echo "3. 只处理冲突文件，不做无关修改。"
    echo "4. 解决后输出总结到 .step/conflict-resolution-summary.md。"
    echo ""
    echo "上下文："
    echo "- change: $change_name"
    echo "- feature branch: $branch"
    echo "- base branch: $base"
    echo ""
    echo "冲突文件："
    for f in "${conflict_files[@]}"; do
      echo "- $f"
    done
    echo ""
    echo "完成后请确保 git diff --name-only --diff-filter=U 为空。"
  } > "$prompt_file"

  local resolver_cmd="${STEP_CONFLICT_RESOLVER:-}"
  if [ -n "$resolver_cmd" ]; then
    (
      cd "$merge_wt"
      CONFLICT_FILES="${conflict_files[*]}" \
      CHANGE_NAME="$change_name" \
      FEATURE_BRANCH="$branch" \
      BASE_BRANCH="$base" \
      bash -lc "$resolver_cmd"
    ) >"$resolver_log" 2>&1
  else
    local prompt
    prompt=$(cat "$prompt_file")
    (
      cd "$merge_wt"
      opencode run "$prompt"
    ) >"$resolver_log" 2>&1
  fi

  if [ ! -f "$summary_file" ]; then
    {
      echo "## 自动生成总结"
      echo "- 已触发 LLM 冲突解决流程"
      echo "- 未检测到 .step/conflict-resolution-summary.md，使用默认摘要"
    } > "$summary_file"
  fi
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
    remember_step_meta "$change_name" "$branch" "$base" "$wt_path"
    echo "✅ Worktree exists: $wt_path"
    return 0
  fi

  if git show-ref --verify --quiet "refs/heads/${branch}"; then
    git worktree add "$wt_path" "$branch"
  else
    git worktree add -b "$branch" "$wt_path" "$base"
  fi

  remember_step_meta "$change_name" "$branch" "$base" "$wt_path"

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

current_task_for_change() {
  local merge_wt="$1"
  local change_name="$2"
  local state_file="$merge_wt/.step/state.yaml"
  local tasks_dir="$merge_wt/.step/changes/${change_name}/tasks"

  # 1) 优先使用 state.yaml 中当前任务（且当前变更一致）
  if [ -f "$state_file" ]; then
    local current_change
    current_change=$(grep '^current_change:' "$state_file" 2>/dev/null | head -1 | sed 's/^current_change:[[:space:]]*//' | tr -d ' "' || true)
    if [ "$current_change" = "$change_name" ]; then
      local current_task
      current_task=$(grep -E '^\s+current:' "$state_file" 2>/dev/null | head -1 | sed 's/.*current:[[:space:]]*//' | tr -d ' "' || true)
      if [ -n "$current_task" ] && [ "$current_task" != "null" ]; then
        printf "%s" "$current_task"
        return
      fi
    fi
  fi

  [ -d "$tasks_dir" ] || { printf ""; return; }

  # 2) 回退：寻找 in_progress 任务
  local tf=""
  for tf in "$tasks_dir"/*.yaml; do
    [ -f "$tf" ] || continue
    if grep -q '^status:[[:space:]]*in_progress' "$tf" 2>/dev/null; then
      basename "$tf" .yaml
      return
    fi
  done

  # 3) 再回退：选择最近修改的任务
  local latest=""
  latest=$(ls -t "$tasks_dir"/*.yaml 2>/dev/null | head -1 || true)
  if [ -n "$latest" ] && [ -f "$latest" ]; then
    basename "$latest" .yaml
    return
  fi

  printf ""
}

set_task_status() {
  local merge_wt="$1"
  local change_name="$2"
  local task_slug="$3"
  local status="$4"
  local task_file="$merge_wt/.step/changes/${change_name}/tasks/${task_slug}.yaml"
  [ -f "$task_file" ] || return 1
  sed -i.bak "s/^status:.*/status: ${status}/" "$task_file"
  rm -f "$task_file.bak"
}

run_post_conflict_gate() {
  local merge_wt="$1"
  local change_name="$2"
  local task_slug
  task_slug=$(current_task_for_change "$merge_wt" "$change_name")
  if [ -z "$task_slug" ]; then
    echo "❌ 无法确定当前任务，冲突解决后无法强制 gate lite"
    return 1
  fi
  echo "🔒 冲突解决后强制验证: gate lite ${task_slug}"
  set_task_status "$merge_wt" "$change_name" "$task_slug" "in_progress" || true
  if [ -x "$merge_wt/scripts/gate.sh" ]; then
    if ! bash "$merge_wt/scripts/gate.sh" lite "$task_slug"; then
      echo "❌ 冲突解决后的 gate lite 失败"
      return 1
    fi
  else
    echo "❌ 缺少 gate.sh，无法执行冲突后强制验证"
    return 1
  fi
  return 0
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
    local code_conflicts=()
    local conflict_file=""
    for conflict_file in $conflicts; do
      local strategy
      strategy=$(choose_conflict_strategy "$conflict_file" "$change_name")
      if [ "$strategy" = "manual" ]; then
        code_conflicts+=("$conflict_file")
        echo "  - $conflict_file  => resolve by LLM"
      else
        git -C "$merge_wt" checkout --"$strategy" -- "$conflict_file"
        git -C "$merge_wt" add "$conflict_file"
        echo "  - $conflict_file  => used '$strategy'"
      fi
    done

    if [ "${#code_conflicts[@]}" -gt 0 ]; then
      local resolver_log
      resolver_log="$merge_wt/.step/conflict-resolution.log"
      local summary_file
      summary_file="$merge_wt/.step/conflict-resolution-summary.md"

      if ! run_llm_conflict_resolution "$merge_wt" "$change_name" "$branch" "$base" "$resolver_log" "$summary_file" "${code_conflicts[@]}"; then
        write_conflict_report "$merge_wt" "$change_name" "$branch" "$base" "$resolver_log" "$summary_file" "${code_conflicts[@]}"
        [ -n "$temp_merge_wt" ] && git worktree remove "$temp_merge_wt" --force || true
        echo "❌ 大模型冲突解决失败，请查看 .step/conflict-report.md"
        return 1
      fi

      local unresolved
      unresolved=$(git -C "$merge_wt" diff --name-only --diff-filter=U)
      if [ -n "$unresolved" ]; then
        write_conflict_report "$merge_wt" "$change_name" "$branch" "$base" "$resolver_log" "$summary_file" "${code_conflicts[@]}"
        [ -n "$temp_merge_wt" ] && git worktree remove "$temp_merge_wt" --force || true
        echo "❌ 大模型处理后仍有未解决冲突，请查看 .step/conflict-report.md"
        return 1
      fi

      if ! run_post_conflict_gate "$merge_wt" "$change_name"; then
        write_conflict_report "$merge_wt" "$change_name" "$branch" "$base" "$resolver_log" "$summary_file" "${code_conflicts[@]}"
        [ -n "$temp_merge_wt" ] && git worktree remove "$temp_merge_wt" --force || true
        return 1
      fi

      git -C "$merge_wt" add -A
      write_conflict_report "$merge_wt" "$change_name" "$branch" "$base" "$resolver_log" "$summary_file" "${code_conflicts[@]}"
    fi

    git -C "$merge_wt" commit -m "merge(step): ${change_name} (llm-resolved conflicts)" >/dev/null 2>&1
    echo "✅ Conflicts resolved by LLM and merged"
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
  local change_name="$3"

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
  rm -f "$(meta_file "$change_name")"
}

finalize_worktree() {
  local change_name="$1"
  local auto_yes="${2:-false}"

  if ! worktree_enabled; then
    echo "ℹ️ worktree.enabled=false，跳过合并/归档流程"
    return 0
  fi

  local default_branch
  default_branch=$(change_branch "$change_name")
  local branch
  branch=$(step_feature_branch "$change_name" "$default_branch")
  local base
  base=$(step_base_branch "$change_name")
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
  cleanup_feature_worktree "$branch" "$wt_path" "$change_name"
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
