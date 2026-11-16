# Contributing to Antigravity Protocol for Claude

Thank you for your interest in improving the **Antigravity Protocol for Claude**! 🚀

## Core Principles
1. **Zero Fluff:** Every skill, subagent, and directive must stay lean and high-signal without fighting native Claude Code workflows.
2. **Token Efficiency:** Respect context windows with RTK bash filtering, prompt caching (`promptCacheTtl: 1h`), and isolated subagents.
3. **Native Planning & Verification:** Leverage Claude Code's native `/plan` (`Shift+Tab`), `agents/` subagents (`architect`, `verifier`), and automated test verification instead of writing temporary `.md` files to repo roots.

---

## Adding a New Skill or Subagent
1. Create a skill under `skills/<skill-name>/SKILL.md` or a subagent under `agents/<agent-name>.md`.
2. Add standardized YAML frontmatter:
   ```yaml
   ---
   name: <skill-name>
   description: <Clear explanation of when Claude Code should trigger this skill>
   ---
   ```
3. Test locally with Claude Code:
   ```bash
   cp -r skills/<skill-name> ~/.claude/skills/
   claude
   ```
4. Update `scripts/settings.ps1`, `settings.sh`, `setup-antigravity-claude.bat`, `uninstall.bat`, and `uninstall.sh` if registering as an interactive toggle.
5. Submit a Pull Request!
