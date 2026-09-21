---
name: protecting-main-branch
description: Use when a git project needs to block direct commits or pushes to main — setting up branch protection, replicating the Claude Code PreToolUse + git pre-commit/pre-push hook pattern, or asked to "protect main" or "block commits to main".
---

# Protecting Main Branch

## Overview

Two independent, complementary layers that block direct commits/pushes to
a protected branch (default `main`):

1. **Claude Code hook** — `PreToolUse` on the `Bash` matcher, denies
   `git commit`/`git push` run through Claude Code's Bash tool.
2. **Real git hooks** — `pre-commit` + `pre-push` via `core.hooksPath`,
   denies the same for every git client (terminal, editors, CI).

Neither is hard enforcement: the Claude Code hook only governs that one
tool, and git hooks are bypassable with `--no-verify` by design. For hard
enforcement, use server-side branch protection on GitHub/GitLab.

## When to Use

- User asks to protect/lock down `main`, or block direct commits/pushes to it
- Replicating this pattern (originally from wphilltech.com) into a new repo
- NOT for CI-enforced or server-side branch protection — that's a
  GitHub/GitLab settings change, not something these hooks provide

## Setup

Run the bundled script from anywhere inside the target repo:

```bash
~/.claude/skills/protecting-main-branch/scripts/setup-branch-protection.sh [branch]
```

`branch` defaults to `main`. The script:
- writes `.claude/hooks/block-main-git.sh` and wires it into
  `.claude/settings.json` (merges with existing hooks, doesn't clobber)
- writes `.githooks/pre-commit` + `.githooks/pre-push`, sets
  `git config core.hooksPath .githooks` for the current clone
- appends explanatory sections to `CLAUDE.md` (creates it if missing)

Idempotent — safe to re-run; it skips anything already present.

## After Running

1. Tell the user to run `/hooks` (or start a fresh session) to activate
   the Claude Code hook — the settings watcher only tracks directories
   that existed when the session started.
2. `core.hooksPath` is per-clone, not tracked by git. Every other clone
   (a teammate, a different machine) needs the same one-time
   `git config core.hooksPath .githooks`, or re-run this script there.

## Common Mistakes

- Assuming the Claude Code hook alone is enough — it doesn't stop a
  plain terminal `git push`.
- Forgetting `core.hooksPath` is local config — a fresh clone has no
  protection until someone runs the setup again (or sets the config).
- Expecting `.claude/settings.json` edits to take effect immediately —
  they need `/hooks` or a session restart.
