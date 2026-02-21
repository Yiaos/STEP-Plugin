---
description: "显示 STEP 项目当前健康状态与交付进度。"
---

执行：

```bash
node ${OPENCODE_PLUGIN_ROOT:-$HOME/.config/opencode/tools/step}/scripts/step-core.js status report --root .step
```

如果未初始化 STEP，提示用户先执行 `/step`。
