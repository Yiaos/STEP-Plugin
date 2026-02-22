# Design: Consolidate Bash Inline Node into step-core.js

## 技术方案概述
将散落在 6 个 Bash 文件中的 18 处 `node -e` 内联代码收拢到 step-core.js，Bash 脚本只做薄壳参数转发。

## 关键技术决策
| 决策点 | 选择 | 替代方案 | 理由 |
|--------|------|---------|------|
| manager 入口 | step-core.js `manager` 子命令 | 新建 step-manager.js | 保持单文件零配置，避免 require 路径管理 |
| session-start JSON 生成 | step-core.js `hook session-start` 子命令 | 改用 `<<'EOF'` 禁止展开 | 仅禁止展开不够，还需正确转义换行/引号，Node 的 JSON.stringify 一劳永逸 |
| guard 合并 | step-core.js `guard` 子命令，stdin 接收 payload | 常驻 Node 进程 | 常驻进程增加复杂度，单次调用已足够（~50ms） |
| step-manager.sh 保留 | 保留为薄壳 | 删除并全局替换引用 | 6 个文件 + SKILL.md 引用，薄壳成本低于全局替换风险 |
| task_status_is | step-core.js `task status` 子命令 | 提取为 shared.sh 函数 | shared.sh 内部仍需 `node -e`，不如直接用 step-core.js |
| WORKFLOW 拆分 | 按角色拆为 4 文件 | 保持单文件加折叠标记 | 1507 行单文件维护成本高，按角色拆分职责清晰 |
| Agent dispatch 增强 | guard 中增加 Write/Edit 拦截 | 新增独立 Hook | 复用已有 guard 流程，不增加 Hook 数量 |
| 2-Action Rule | 按 phase 分级阈值 | 完全取消 | findings 机制有价值，降低频率而非取消 |

## 架构变更

### step-core.js 新增子命令树
```
step-core.js
├── state {get|set|validate}     # 已有
├── task {status}                # 新增 P2-3
├── manager                      # 新增 P0-1
│   ├── enter --mode [--change] [--task]
│   ├── transition --to <phase>
│   ├── phase-gate --from --to
│   ├── assert-phase --tool [--command]
│   ├── assert-dispatch --tool --agent
│   ├── check-action --tool [--command]
│   ├── status-line
│   └── cancel [--change]        # 新增 P3
├── guard                        # 新增 P1-1
│   └── (stdin: JSON payload, 一次性完成 auto-enter + assert-phase + check-action)
└── hook                         # 新增 P0-2
    └── session-start --state --phase --change --task --skill [--warning]
```

### 函数迁移映射
step-manager.sh 14 个函数 → step-core.js 对应实现：
- `get_state_field` / `get_config_field` / `set_state_fields` → 复用已有 readJson/writeJsonAtomic/getPathValue/setPathValue
- `phase_for_mode` / `can_transition` / `is_phase_allowed_for_tool` → 纯映射表（常量对象）
- `is_bash_command_allowed_in_phase` → 只读命令白名单 + phase 规则
- `check_bash_command` → 复用已有 tokenize + sanitizeTokens
- `phase_gate` / `enter` / `transition` / `assert_phase` / `assert_dispatch` → 组合上述基础函数

### 数据流变更

**改前（PreToolUse）**:
```
pretool-guard.sh → node -e (parse payload)
                 → node -e (read state)
                 → step-manager.sh assert-phase → node -e (read state again)
                 → step-manager.sh check-action → node -e (tokenize)
                 → cat state.json | head -25
```

**改后（PreToolUse）**:
```
pretool-guard.sh → stdin | node step-core.js guard
                   (内部一次性: parse payload + read state + assert-phase + check-action + output summary)
```

## 依赖变更
无。零外部依赖约束不变。

## 新增设计：WORKFLOW.md 拆分

拆分后结构：
```
WORKFLOW.md (~700 行)       — Phase 0-5 定义、流转规则、保证与限制、自主操作规则、Post-MVP 流程、场景覆盖机制
docs/
  examples.md (~400 行)    — Lite 完整流程、对话示例、Post-MVP 场景示例
  hooks.md (~200 行)       — Hook/Command 实现细节、AGENTS.md 模板、初始化脚本说明
  design-notes.md (~200 行) — 9 个反馈对应记录、设计决策背景
```

WORKFLOW.md 中 Lite Mode 保留 ~30 行精简段落，指向 `docs/examples.md`。

## 新增设计：Agent Dispatch 增强

guard 子命令中增加 dispatch 检查逻辑：
```
if mode == "full"
   && phase in [phase-4-execution, phase-5-review]
   && require_dispatch == true
   && tool in [Write, Edit]
   && tool not in config.enforcement.bypass_tools
   → 拒绝，提示通过 subagent 执行
```

config.json 新增字段：
```json
{
  "enforcement": {
    "require_dispatch": true,
    "bypass_tools": []
  }
}
```

## 新增设计：2-Action Rule 分级

阈值映射表：
| Phase | 阈值 | 理由 |
|-------|------|------|
| phase-0-discovery, lite-l1 | 2 | 探索阶段，发现密度高 |
| phase-1-prd, phase-2-design, phase-3-plan | 3 | 规划阶段，中等频率 |
| phase-4-execution, phase-5-review, lite-l2, lite-l3 | 4 | 执行阶段，动作密集 |
| idle, done | 不检查 | 无活跃变更 |

修改点：step-stop-check.sh 中 findings 检查逻辑读取 current_phase，查表获取阈值。SKILL.md 和 WORKFLOW.md 中规则描述同步更新。

## 风险与约束
- R1: step-core.js 从 1036 行增长到 ~1620 行 — 可接受，单文件工具 2000 行以内可控
- R2: 迁移过程中可能引入行为差异 — 通过现有 15 个测试脚本逐步验证
- R3: macOS bash 3.2 兼容性 — 薄壳只用基础语法，无风险
- R4: Agent dispatch 增强可能过于严格 — bypass_tools 白名单提供逃生口
- R5: 2-Action Rule 阈值调整可能导致 findings 更新不及时 — Phase 0 保持原阈值，风险可控
- C1: 迁移顺序必须按依赖：先基础函数 → 再组合函数 → 最后薄壳替换
