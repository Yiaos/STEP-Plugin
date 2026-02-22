#!/bin/bash
# T-037 测试：install/uninstall 插件注入 wiring

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
PASS=0; FAIL=0; TOTAL=0

assert() {
  TOTAL=$((TOTAL + 1))
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then
    echo "  ✅ $name"; PASS=$((PASS + 1))
  else
    echo "  ❌ $name"; FAIL=$((FAIL + 1))
  fi
}

echo "=== T-037: install plugin wiring ==="

assert "[S-install-wiring-01] install creates plugin symlink and lib copy" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf "\$tmpdir"' EXIT
  HOME_DIR=\"\$tmpdir/home\"
  ROOT_DIR=\"\$HOME_DIR/.config/opencode/tools/step\"
  mkdir -p \"\$HOME_DIR\"
  HOME=\"\$HOME_DIR\" OPENCODE_PLUGIN_ROOT=\"\$ROOT_DIR\" bash '$SCRIPT_DIR/install.sh' --force >/dev/null
  [ -L \"\$HOME_DIR/.config/opencode/plugins/step.js\" ]
  [ -d \"\$ROOT_DIR/lib/core\" ]
  [ -f \"\$ROOT_DIR/.opencode/plugins/step.js\" ]
"

assert "[S-install-wiring-02] uninstall removes plugin symlink" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf "\$tmpdir"' EXIT
  HOME_DIR=\"\$tmpdir/home\"
  ROOT_DIR=\"\$HOME_DIR/.config/opencode/tools/step\"
  mkdir -p \"\$HOME_DIR\"
  HOME=\"\$HOME_DIR\" OPENCODE_PLUGIN_ROOT=\"\$ROOT_DIR\" bash '$SCRIPT_DIR/install.sh' --force >/dev/null
  HOME=\"\$HOME_DIR\" OPENCODE_PLUGIN_ROOT=\"\$ROOT_DIR\" bash '$SCRIPT_DIR/uninstall.sh' >/dev/null
  [ ! -e \"\$HOME_DIR/.config/opencode/plugins/step.js\" ]
  [ ! -d \"\$ROOT_DIR\" ]
"

echo ""
echo "=== 结果: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
