# STEP Design Notes

## 反馈映射

1. Phase 0/2 改为开放式讨论
2. Post-MVP 统一变更结构
3. 场景规则统一为 BDD Given/When/Then
4. Hook 负责自动注入和校验
5. 统一 routing/file_routing/gate 配置
6. Review 双阶段：Spec Compliance -> Code Quality
7. Gate 失败先分析后修复，最多 3 轮
8. `/step` 负责初始化和恢复
9. 测试写作 agent 可配置
10. `step-core.js` 分层拆分到 `lib/core/*`（parser/guard/validator）
11. phase/mode/dispatch 规则拆分到 `lib/core/phase-policy.js`

## 实现取舍

- 采用零依赖（Node.js + Bash）
- 脚本可运行性优先于提示词约束
- 软硬保证分层：脚本做硬保证，提示词做软约束
