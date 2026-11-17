#!/usr/bin/env bash
set -e

echo "=========================================================================="
echo "             UNINSTALL ANTIGRAVITY PROTOCOL SUITE                         "
echo "=========================================================================="
echo "This will safely remove Antigravity skills, configuration, and prompt caching."
echo "(Your personal custom skills outside this suite will NOT be touched)"
echo ""

read -p "Are you sure you want to proceed? (y/N): " confirm
if [[ "$confirm" != [yY] ]]; then
    echo "Uninstall cancelled."
    exit 0
fi

CLAUDE_DIR="$HOME/.claude"
SKILLS_DIR="$CLAUDE_DIR/skills"
DISABLED_DIR="$CLAUDE_DIR/skills-disabled"
CATALOG_DIR="$CLAUDE_DIR/skills-catalog"
BIN_DIR="$CLAUDE_DIR/bin"

ALL_SKILLS=(
    "antigravity"
    "antigravity-planner"
    "neural-context"
    "caveman"
    "session-metrics"
    "session-report"
    "graphify"
    "frontend-design"
    "test-driven-development"
    "systematic-debugging"
    "verification-before-completion"
    "web-artifacts-builder"
    "xlsx"
    "pdf"
    "docx"
)

echo "[1/5] Removing Antigravity skills, subagents, and catalog..."
for s in "${ALL_SKILLS[@]}"; do
    rm -rf "$SKILLS_DIR/$s" 2>/dev/null || true
    rm -rf "$DISABLED_DIR/$s" 2>/dev/null || true
done
rm -f "$CLAUDE_DIR/agents/architect.md" "$CLAUDE_DIR/agents/verifier.md" 2>/dev/null || true
rm -f "$CLAUDE_DIR/output-styles/simple-english.md" 2>/dev/null || true
rm -rf "$CATALOG_DIR" 2>/dev/null || true

echo "[2/5] Restoring CLAUDE.md..."
if [ -f "$CLAUDE_DIR/CLAUDE.md.bak" ]; then
    mv -f "$CLAUDE_DIR/CLAUDE.md.bak" "$CLAUDE_DIR/CLAUDE.md"
    echo "  -> Restored original CLAUDE.md from backup."
elif [ -f "$CLAUDE_DIR/CLAUDE.md" ]; then
    if grep -q "ANTIGRAVITY OPERATING SYSTEM DIRECTIVE" "$CLAUDE_DIR/CLAUDE.md"; then
        rm -f "$CLAUDE_DIR/CLAUDE.md"
        echo "  -> Antigravity CLAUDE.md removed."
    fi
fi

echo "[3/5] Cleaning up hooks and launchers..."
rm -f "$CLAUDE_DIR/RTK.md" 2>/dev/null || true
rm -f "$BIN_DIR/agy-settings" 2>/dev/null || true
rm -f "$BIN_DIR/settings.sh" 2>/dev/null || true

echo "[4/5] Clearing prompt caching variables & settings.json keys..."
remove_line() {
    local pattern="$1"
    local file="$2"
    [ -f "$file" ] || return 0
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "$pattern" "$file" 2>/dev/null || true
    else
        sed -i "$pattern" "$file" 2>/dev/null || true
    fi
}
remove_line '/ENABLE_PROMPT_CACHING_1H/d' "$HOME/.bashrc"
remove_line '/ENABLE_PROMPT_CACHING_1H/d' "$HOME/.zshrc"
if command -v python3 >/dev/null 2>&1 && [ -f "$CLAUDE_DIR/settings.json" ]; then
    python3 -c '
import json, os
p = os.path.expanduser("~/.claude/settings.json")
try:
    with open(p, "r", encoding="utf-8") as f: data = json.load(f)
except Exception:
    data = None
if isinstance(data, dict):
    data.pop("promptCacheTtl", None)
    data.pop("subagentPromptCacheTtl", None)
    if data.get("outputStyle") == "Simple English":
        data.pop("outputStyle", None)
    if data.get("advisorModel") == "fable":
        data.pop("advisorModel", None)
    hooks = data.get("hooks")
    if isinstance(hooks, dict) and isinstance(hooks.get("PreToolUse"), list):
        kept = [e for e in hooks["PreToolUse"] if not any("rtk hook claude" in str(h.get("command", "")) for h in (e.get("hooks") or []))]
        if kept: hooks["PreToolUse"] = kept
        else: hooks.pop("PreToolUse", None)
        if not hooks: data.pop("hooks", None)
    with open(p, "w", encoding="utf-8") as f: json.dump(data, f, indent=2)
' 2>/dev/null || true
fi

echo "[5/5] Removing config..."
rm -f "$CLAUDE_DIR/antigravity.json"

echo ""
echo "[SUCCESS] Antigravity Suite uninstalled cleanly."
