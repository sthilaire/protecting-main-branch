# protecting-main-branch

Stop accidental commits and pushes straight to `main` — two small, independent
layers you can drop into any git repo in one command.

1. **Claude Code hook** — if you use [Claude Code](https://claude.com/claude-code),
   blocks `git commit`/`git push` run through its Bash tool while on `main`.
2. **Real git hooks** (`pre-commit` + `pre-push`) — blocks the same for every
   git client: your terminal, your editor, CI, anything.

Neither is a hard security boundary. The Claude Code hook only governs that
one tool, and git hooks are bypassable with `--no-verify` by design (that's
intentional — see [Limitations](#limitations)). Think of this as a guardrail
against mistakes, not a permissions system. For real enforcement, use your
git host's server-side branch protection (GitHub/GitLab settings).

## Quick start

Clone this repo, then run its script from inside the project you want to protect:

```bash
git clone https://github.com/sthilaire/protecting-main-branch.git /tmp/protecting-main-branch
/tmp/protecting-main-branch/scripts/setup-branch-protection.sh
```

That's it. It protects `main` by default. To protect a different branch name:

```bash
/tmp/protecting-main-branch/scripts/setup-branch-protection.sh trunk
```

The script is idempotent — safe to re-run, and it won't duplicate anything
or clobber existing `.claude/settings.json` hooks.

### What it creates in your project

```
.claude/hooks/block-main-git.sh   # Claude Code hook script
.claude/settings.json             # wires the hook in (merged, not overwritten)
.githooks/pre-commit              # rejects a commit while on the protected branch
.githooks/pre-push                # rejects a push targeting the protected branch
CLAUDE.md                         # notes on both mechanisms (created or appended to)
```

It also runs `git config core.hooksPath .githooks` for you, in the current
clone only (see below).

## The one manual step

`core.hooksPath` is git config, not a tracked file — git deliberately
doesn't let a repo silently enable hooks for everyone who clones it. That
means:

- The clone you ran the script in is protected immediately.
- Every **other** clone (a teammate's machine, a CI runner, a fresh checkout)
  needs the same one-time command, run from inside that clone:

  ```bash
  git config core.hooksPath .githooks
  ```

  (or just re-run `setup-branch-protection.sh` there — it's idempotent).

## Using it as a Claude Code skill

This repo doubles as a [Claude Code](https://claude.com/claude-code) skill.
Clone it directly into your skills directory and Claude will pick it up:

```bash
git clone https://github.com/sthilaire/protecting-main-branch.git ~/.claude/skills/protecting-main-branch
```

Claude will then reach for it whenever you ask to protect `main`, block
direct commits, or set up branch protection — see `SKILL.md` for the full
trigger description.

## Limitations

- **The Claude Code hook only covers Claude Code's Bash tool.** A plain
  terminal `git push` from the same machine isn't touched by it.
- **`--no-verify` bypasses both git hooks by design.** Git hooks are a
  local convention, not a security boundary — anyone with a checkout can
  disable them. If you need guarantees regardless of the developer's local
  setup, use server-side branch protection on your git host instead.
- **`.claude/settings.json` changes need a reload.** Run `/hooks` inside
  Claude Code (or start a fresh session) to activate a newly added or
  edited hook — the config watcher only tracks directories that existed
  when the session started.
- Fast-forward merges and `git reset --hard` skip `pre-commit` (no new
  commit object is created), but `pre-push` still catches them before
  anything leaves the machine.

## License

MIT — see [LICENSE](LICENSE).
