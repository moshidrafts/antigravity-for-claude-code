#!/usr/bin/env bash
set -e

clear
echo "=========================================================================="
echo "               ANTIGRAVITY PROTOCOL SUITE FOR CLAUDE                      "
echo "=========================================================================="

CLAUDE_DIR="$HOME/.claude"
SKILLS_DIR="$CLAUDE_DIR/skills"
AGENTS_DIR="$CLAUDE_DIR/agents"
STYLES_DIR="$CLAUDE_DIR/output-styles"
CATALOG_DIR="$CLAUDE_DIR/skills-catalog"
BIN_DIR="$CLAUDE_DIR/bin"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_SKILLS="$SCRIPT_DIR/skills"
LOCAL_AGENTS="$SCRIPT_DIR/agents"
LOCAL_STYLES="$SCRIPT_DIR/output-styles"

mkdir -p "$CLAUDE_DIR" "$SKILLS_DIR" "$AGENTS_DIR" "$STYLES_DIR" "$CATALOG_DIR" "$BIN_DIR"

echo -n "[1/6] Deploying 12 skills, 2 subagents, and Simple English style to $CLAUDE_DIR... "
for legacy in "antigravity" "antigravity-planner" "neural-context"; do
    rm -rf "$SKILLS_DIR/$legacy" "$CATALOG_DIR/$legacy" "$CLAUDE_DIR/skills-disabled/$legacy" 2>/dev/null || true
done
if [ -d "$LOCAL_SKILLS" ]; then
    cp -r "$LOCAL_SKILLS"/* "$SKILLS_DIR/"
    cp -r "$LOCAL_SKILLS"/* "$CATALOG_DIR/"
fi
if [ -d "$LOCAL_AGENTS" ]; then
    cp -f "$LOCAL_AGENTS"/*.md "$AGENTS_DIR/" 2>/dev/null || true
fi
if [ -d "$LOCAL_STYLES" ]; then
    cp -f "$LOCAL_STYLES"/*.md "$STYLES_DIR/" 2>/dev/null || true
fi
echo "[DONE]"

echo "[2/6] Configuring global CLAUDE.md..."
CLAUDE_MD_DEST="$CLAUDE_DIR/CLAUDE.md"
CLAUDE_MD_SRC="$SCRIPT_DIR/CLAUDE.md"

if [ -f "$CLAUDE_MD_DEST" ]; then
    if cmp -s "$CLAUDE_MD_DEST" "$CLAUDE_MD_SRC"; then
        echo "  -> Global CLAUDE.md is already up to date."
    else
        IS_ANTIGRAVITY=0
        grep -q "ANTIGRAVITY OPERATING SYSTEM DIRECTIVE" "$CLAUDE_MD_DEST" && IS_ANTIGRAVITY=1 || true
        echo ""
        echo "  [!] An existing CLAUDE.md was detected at: $CLAUDE_MD_DEST"
        [ "$IS_ANTIGRAVITY" = "1" ] && echo "      It differs from the repo copy (you may have customized it)."
        echo "      How would you like to handle this?"
        echo "      [O] Overwrite (backs up existing file to CLAUDE.md.bak)"
        echo "      [K] Keep existing CLAUDE.md untouched"
        [ "$IS_ANTIGRAVITY" = "0" ] && echo "      [A] Append Antigravity Protocol to the end of existing file"
        echo "      [C] Cancel / Exit setup without modifying CLAUDE.md"
        read -p "      Select an option: " mdChoice
        case "$mdChoice" in
            [kK])
                echo "  -> Kept your existing CLAUDE.md untouched."
                ;;
            [aA])
                if [ "$IS_ANTIGRAVITY" = "0" ]; then
                    cp "$CLAUDE_MD_DEST" "$CLAUDE_MD_DEST.bak"
                    echo "" >> "$CLAUDE_MD_DEST"
                    cat "$CLAUDE_MD_SRC" >> "$CLAUDE_MD_DEST"
                    echo "  -> Antigravity appended to existing CLAUDE.md (backup saved to CLAUDE.md.bak)"
                else
                    echo "  -> Kept your existing CLAUDE.md untouched."
                fi
                ;;
            [cC])
                echo "Setup cancelled. No modifications were made to CLAUDE.md."
                exit 0
                ;;
            [oO])
                cp "$CLAUDE_MD_DEST" "$CLAUDE_MD_DEST.bak"
                cp -f "$CLAUDE_MD_SRC" "$CLAUDE_MD_DEST"
                echo "  -> CLAUDE.md overwritten (original backed up to CLAUDE.md.bak)"
                ;;
            *)
                if [ "$IS_ANTIGRAVITY" = "1" ]; then
                    echo "  -> Kept your existing CLAUDE.md untouched."
                else
                    cp "$CLAUDE_MD_DEST" "$CLAUDE_MD_DEST.bak"
                    cp -f "$CLAUDE_MD_SRC" "$CLAUDE_MD_DEST"
                    echo "  -> CLAUDE.md overwritten (original backed up to CLAUDE.md.bak)"
                fi
                ;;
        esac
    fi
else
    cp -f "$CLAUDE_MD_SRC" "$CLAUDE_MD_DEST"
    echo "  -> Global CLAUDE.md deployed successfully."
fi

echo -n "[3/6] Configuring 1h caching, Simple English style & native settings... "
export ENABLE_PROMPT_CACHING_1H=1
grep -q "ENABLE_PROMPT_CACHING_1H" "$HOME/.bashrc" 2>/dev/null || echo "export ENABLE_PROMPT_CACHING_1H=1" >> "$HOME/.bashrc"
[ -f "$HOME/.zshrc" ] && (grep -q "ENABLE_PROMPT_CACHING_1H" "$HOME/.zshrc" 2>/dev/null || echo "export ENABLE_PROMPT_CACHING_1H=1" >> "$HOME/.zshrc")
if command -v python3 >/dev/null 2>&1; then
    python3 -c '
import json, os
p = os.path.expanduser("~/.claude/settings.json")
data = {}
if os.path.exists(p):
    try:
        with open(p, "r", encoding="utf-8") as f: data = json.load(f)
    except Exception: data = {}
data["promptCacheTtl"] = "1h"
data["subagentPromptCacheTtl"] = "1h"
data["outputStyle"] = "Simple English"
data["advisorModel"] = "fable"
data["inputNeededNotifEnabled"] = True
data["agentPushNotifEnabled"] = True
mk = data.setdefault("extraKnownMarketplaces", {})
mk.setdefault("centminmod", {"source": {"source": "github", "repo": "centminmod/claude-plugins"}})
mk.setdefault("claude-community", {"source": {"source": "github", "repo": "anthropics/claude-plugins-community"}})
with open(p, "w", encoding="utf-8") as f: json.dump(data, f, indent=2)
' 2>/dev/null || true
fi
echo "[DONE]"

echo -n "[4/6] Registering global 'agy-settings' in PATH... "
cp -f "$SCRIPT_DIR/settings.sh" "$BIN_DIR/settings.sh"
cat << 'EOF' > "$BIN_DIR/agy-settings"
#!/usr/bin/env bash
bash "$HOME/.claude/bin/settings.sh"
EOF
chmod +x "$BIN_DIR/agy-settings" "$BIN_DIR/settings.sh"

if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    export PATH="$BIN_DIR:$PATH"
    echo "export PATH=\"$BIN_DIR:\$PATH\"" >> "$HOME/.bashrc"
    [ -f "$HOME/.zshrc" ] && echo "export PATH=\"$BIN_DIR:\$PATH\"" >> "$HOME/.zshrc"
fi
echo "[DONE]"

# 5. Register Vetted Developer Plugins & Compiler LSPs if claude is present
if command -v claude >/dev/null 2>&1; then
    echo "[5/6] Registering Vetted Developer Plugins & Compiler LSPs..."
    for p in pyright-lsp@claude-plugins-official typescript-lsp@claude-plugins-official code-review@claude-plugins-official code-simplifier@claude-plugins-official commit-commands@claude-plugins-official skill-creator@claude-plugins-official claude-security@claude-plugins-official mcp-server-dev@claude-plugins-official mcp-tunnels@claude-plugins-official agent-sdk-dev@claude-plugins-official; do
        claude plugin install "$p" >/dev/null 2>&1 || true
    done
    echo "  -> Vetted developer plugins & compiler LSPs configured (clean, zero colon spam)."
fi

echo -n "[6/6] Copying Custom Instructions to Clipboard... "
if command -v pbcopy >/dev/null 2>&1; then
    cat "$SCRIPT_DIR/CLAUDE.md" | pbcopy
    echo "[COPIED (pbcopy)]"
elif command -v xclip >/dev/null 2>&1; then
    xclip -selection clipboard < "$SCRIPT_DIR/CLAUDE.md"
    echo "[COPIED (xclip)]"
elif command -v wl-copy >/dev/null 2>&1; then
    wl-copy < "$SCRIPT_DIR/CLAUDE.md"
    echo "[COPIED (wl-copy)]"
else
    echo "[MANUAL COPY REQUIRED]"
fi

echo ""
echo "=========================================================================="
echo "           1. CLAUDE DESKTOP CUSTOM INSTRUCTIONS (COPIED!)                "
echo "=========================================================================="
echo "+------------------------------------------------------------------------+"
echo "|  * ZERO CONVERSATIONAL FLUFF (Immediate engineering answers)           |"
echo "|  * READ BEFORE EDITING & RIPPLE CHECK (Trace callers first)            |"
echo "|  * NATIVE PLAN MODE & SUBAGENTS (No junk .md files in repo roots)      |"
echo "|  * VERIFY BEFORE COMPLETION (Run tests/builds before claiming done)    |"
echo "|  * TARGETED CHUNK DIFFS (Never dump entire files)                      |"
echo "+------------------------------------------------------------------------+"

echo ""
echo "=========================================================================="
echo "                      2. WHAT TO DO NEXT                                  "
echo "=========================================================================="
echo "  1. Open Claude Desktop (or Claude.ai web)."
echo "  2. Go to: Settings -> Custom Instructions."
echo "  3. Press Cmd + V (or Ctrl + V) to paste instructions."
echo "  4. Click Save."
echo "  5. Start coding in Claude Desktop's Code tab (or run 'claude' in your terminal)!"

echo ""
echo "=========================================================================="
echo "                    3. SETTINGS & GLOBAL COMMAND                          "
echo "=========================================================================="
echo "  * All 12 skills, 2 subagents, and 1-hour caching are ENABLED by default."
echo "  * You can now run 'agy-settings' from ANY terminal!"
echo "  * Or run './settings.sh' anytime from this folder."
echo "=========================================================================="
echo ""
read -p "Run settings now? (y/N): " ans
if [[ "$ans" == [yY] ]]; then
    bash "$BIN_DIR/settings.sh"
fi
