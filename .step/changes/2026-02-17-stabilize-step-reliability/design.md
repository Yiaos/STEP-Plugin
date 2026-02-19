# Design: STEP Trigger & Enforcement Reliability

## 方案概览
采用“统一入口 + 前置拦截 + 兼容保留”的增量设计。

### 1) 统一入口层（Trigger Layer）
- 新增 `scripts/step-manager.sh`：
  - `doctor`：统一调用 `scripts/step-doctor.sh`
  - `check-action`：统一动作前检查（本次先支持 Bash）

### 2) 约束层（Enforcement Layer）
- 在 `step-manager check-action` 中复用 `dangerous_executables` 来源：
  - 首选 `.step/config.json` 的 `gate.dangerous_executables`
  - 无配置时使用 `step-core.js` 默认兜底黑名单
- `skills/step/SKILL.md` 的 PreToolUse 在 Bash 场景调用 `step-manager check-action`。

### 3) 兼容层（Compatibility Layer）
- 保留 `gate.sh -> step-core.js` 现有黑名单逻辑，避免回归。
- 新能力仅扩展“非 gate Bash”拦截，不替换 gate 内核实现。

## 模式策略
- `strict`（默认）：命中黑名单直接 block（返回非 0）。
- `soft`（后续）：只警告不阻断（本次先不做）。

## 风险与缓解
- 风险：命令字符串提取不准确导致误拦截。
  - 缓解：仅按 executable 粒度匹配，和 gate 保持一致语义。
- 风险：PreToolUse 传参差异导致空命令。
  - 缓解：空命令视为放行，不误拦截。
