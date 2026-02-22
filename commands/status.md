---
description: "Show current STEP project health and delivery progress."
---

Run:

```bash
node ${OPENCODE_PLUGIN_ROOT:-$HOME/.config/opencode/tools/step}/scripts/step-core.js status report --root .step
```

If STEP is not initialized, instruct the user to run `/step` first.

After status output, if wrapping up, call `step:verification-before-completion` for final verification.
