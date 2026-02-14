# Baseline

> 状态: ✅ 已冻结（2026-02-15）

## Goal
一句话：为 STEP Plugin 自身提供注意力管理增强，解决 LLM 在长会话中遗忘进度/决策、以及 Stop hook 缺乏真实检查的问题。

## Non-Goal（明确不做的事）
- NG-1: 不重写 STEP 核心协议流程（Phase 0-5 流程不变）
- NG-2: 不实现文件写保护（已证明无法通过 opencode 机制保证）
- NG-3: 不新增 Agent 角色（4 角色体系不变）

## MVP Scope（按优先级排序）

### P0 — Must Have
- [x] F-1: PreToolUse 注入内容增强 — state.yaml 头部嵌入行为规则（如"检查 progress_log 是否需要更新"），使 `cat | head -25` 同时注入规则和数据
- [x] F-2: SKILL.md 正文增加注意力规则 — 显式写明"当你看到 state.yaml 被注入时，检查是否需要更新 progress_log / key_decisions"
- [x] F-3: Stop hook 增加真实检查 — 将 echo 提醒改为脚本，检查 state.yaml 的 last_updated 是否为当天、progress_log 是否有本次条目
- [x] F-4: step-init.sh 检测逻辑增强 — 识别非标准项目结构（如 STEP 自身的 scripts/, agents/, commands/, hooks/）

### P1 — Should Have
- [x] F-6: 2-Action Rule 文字强化 — SKILL.md Phase 4 段落显式写入"每 2 次工具调用后检查进度更新需求"
- [x] F-7: Pre-decision Read 规则 — SKILL.md 加入"修改文件前必须先 Read，不得凭记忆编辑"的显式规则

### P2 — Nice to Have
- [x] F-8: 对比文档修正 — 更新 STEP-vs-planning-with-files.md，修正"STEP 不处理遗忘问题"的错误描述

## User Stories
- US-1: 作为使用 STEP 的开发者，我希望 LLM 在长会话中自动被提醒更新进度，以便我在下次会话能恢复完整上下文
- US-2: 作为使用 STEP 的开发者，我希望会话结束前有真实检查（而非仅提醒），以便关键状态不会丢失
- US-3: 作为使用 STEP 的开发者，我希望 step-init.sh 能识别各种项目结构，以便非标准项目也能正确初始化

## Acceptance Contract（验收口径）
- AC-1: PreToolUse 注入的前 20 行同时包含行为规则和状态数据
- AC-2: SKILL.md 包含显式注意力管理段落
- AC-3: Stop hook 运行脚本并输出结构化检查结果（pass/warn/fail）
- AC-4: step-init.sh 对 STEP 项目自身运行 detect_project() 输出正确的项目类型信息
- AC-5: 所有变更通过 gate.sh standard 检查
- AC-6: 对比文档中关于 STEP 遗忘处理的描述已修正

## Constraints（不可违反约束）
- C-1: 不破坏现有 STEP 协议流程（所有现有 .step/ 项目不受影响）
- C-2: install.sh 必须能正确安装所有新增文件
- C-3: state.yaml 模板向后兼容（新字段有默认值）
- C-4: 所有脚本兼容 macOS (bash 3.2+) 和 Linux (bash 4+)
- C-5: test_writing model 通过 config.yaml 配置，不硬编码

## 状态
- 冻结时间: 2026-02-15
- 修改方式: 必须通过 Change Request
