# Findings: Consolidate Bash Inline Node into step-core.js

## 探索发现

### F-1: node -e 内联分布
- step-manager.sh: 6 处（get_state_field, get_config_field, get_config_bool, set_state_fields, check_bash_command, status_line 内部）
- session-start.sh: 1 处（escape_for_json 内部）
- step-pretool-guard.sh: 3 处（extract_field, auto_enter_if_idle x2）
- step-stop-check.sh: 3 处（task_status_is, get_progress_log, check_last_updated）
- step-archive.sh: 1 处（task_status_is）
- step-worktree.sh: 2 处（task_status_is, read_worktree_config）
- step-init.sh: 2 处（inject agents, set timestamp）
- 合计: 18 处

### F-2: step-core.js 已有可复用函数
- readJson / writeJsonAtomic — JSON 文件读写
- getPathValue / setPathValue — 嵌套路径访问
- tokenize / sanitizeTokens — Bash 命令解析
- readTask — 支持 .md 和 .json 格式的 task 读取
- isoNow — 时间戳生成
- 这些函数覆盖了 step-manager.sh 约 60% 的内联逻辑

### F-3: session-start.sh 转义 bug 确认
- 第 61-75 行 `escape_for_json` 只处理 `\` `"` 换行 回车 制表符
- 未处理 `$` 符号
- 第 164 行 `cat <<EOF` 会做 Bash 变量展开
- 如果 baseline.md 包含 `$HOME` 会被展开为实际路径

### F-4: task_status_is 三处定义完全相同
- step-archive.sh:12-26
- step-worktree.sh:403-417
- step-stop-check.sh:22-36
- 均为 `node -e` 读取 task .md 文件，提取 JSON 中的 status 字段

### F-5: pretool-guard.sh 进程启动链
- 最坏情况（Bash 命令）: 5 个 Node 进程
- 最好情况（Write/Edit）: 3 个 Node 进程
- Phase 4 密集编码时每次文件写入都付出此开销
