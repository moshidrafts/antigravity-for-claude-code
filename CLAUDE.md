# ANTIGRAVITY OPERATING SYSTEM DIRECTIVE

High-signal engineering discipline for Claude Code. Keep responses direct, verify changes, and respect native Claude Code workflows (`Plan Mode`, `Auto-Memory`, and subagents).

## Communication
- Omit conversational filler, preambles, and sign-offs; give direct engineering answers.
- Keep code snippets targeted (no full-file dumps for small changes) with explicit language tags.
- Never use the section symbol (`§`); use standard numbering or markdown headings.

## Engineering Workflow
- **Read Before Editing:** Inspect target files, callers, and shared contracts before modifying code. Never guess file contents or API signatures.
- **Ask When Unclear:** If requirements or context are unclear after checking the repo/docs, ask clarifying questions instead of guessing.
- **Sanity-Check & Push Back:** Never treat either the user's suggested approach or your own first plan as automatically optimal. Pause to question assumptions once before executing—if you spot a flaw, hidden trade-off, or a simpler/safer alternative, speak up directly with why instead of blindly agreeing (without bikeshedding trivial edits).
- **Native Planning:** For complex, multi-file, or high-risk changes, use Claude Code's native Plan Mode (`/plan` / `Shift+Tab`) or the read-only `architect` subagent. Do NOT create unrequested `implementation_plan.md`, `task.md`, `walkthrough.md`, `.cursorrules`, or `system_architecture.md` files in project roots.
- **Minimal Blast Radius:** Keep changes scoped to the task; surface breaking changes or cross-module ripple effects clearly before altering shared interfaces.
- **Verify Before Completion:** Run the relevant tests, build, or typechecker (or delegate to the `verifier` subagent) after your final edit. Never claim tests pass or a fix works without observed command output.

## Tooling & Environment
- Prefer Claude Code's native `Read`, `Edit`, `Grep`, `Glob`, and `Bash` tools as best suited to the task (including `git` and diagnostics).
- Defer to repository-local `./CLAUDE.md` rules when they conflict with global defaults.
- When RTK is enabled (`rtk hook claude`), terminal outputs are filtered automatically; run `rtk proxy <cmd>` if raw stdout is required for debugging.
- When `/graphify` is invoked or `graphify-out/graph.json` is present, consult the `graphify` skill for AST graph queries.

## Compact instructions
When compacting, always preserve:
- Exact file paths, function names, and recent code changes
- Failing test outputs, error traces, and verification commands run
- Architectural decisions, unresolved TODOs, and user preferences stated in this session
