#!/bin/bash
# Sets up main-branch protection in the current git repo:
#   - Claude Code PreToolUse hook (blocks git commit/push via the Bash tool)
#   - real git pre-commit/pre-push hooks via core.hooksPath
#   - notes appended to CLAUDE.md
# Idempotent: safe to re-run, skips anything already present.
set -euo pipefail

branch="${1:-main}"
repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "Not inside a git repo." >&2; exit 1; }
cd "$repo_root"

# --- 1. Claude Code hook script ---
mkdir -p .claude/hooks
cat > .claude/hooks/block-main-git.sh <<EOF
#!/bin/bash
command=\$(jq -r '.tool_input.command // empty')

if [[ "\$command" =~ git\\ (commit|push) ]]; then
  branch=\$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  if [[ "\$branch" == "$branch" ]]; then
    echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Direct git commit/push to $branch is blocked. Create a feature branch first."}}'
  fi
fi
exit 0
EOF
chmod +x .claude/hooks/block-main-git.sh

# --- 2. Wire it into .claude/settings.json (merge, don't clobber) ---
if [ ! -f .claude/settings.json ]; then
  cat > .claude/settings.json <<'EOF'
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/hooks/block-main-git.sh"
          }
        ]
      }
    ]
  }
}
EOF
else
  tmp=$(mktemp)
  jq '(.hooks.PreToolUse //= [])
      | if any(.hooks.PreToolUse[]?; .matcher == "Bash" and (.hooks[]?.command == "bash .claude/hooks/block-main-git.sh"))
        then .
        else .hooks.PreToolUse += [{"matcher":"Bash","hooks":[{"type":"command","command":"bash .claude/hooks/block-main-git.sh"}]}]
        end' .claude/settings.json > "$tmp"
  mv "$tmp" .claude/settings.json
fi

# --- 3. Real git hooks ---
mkdir -p .githooks
cat > .githooks/pre-commit <<EOF
#!/bin/bash
protected_branch="$branch"
branch=\$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

if [ "\$branch" = "\$protected_branch" ]; then
  echo "Commit to '\$protected_branch' rejected. Create a feature branch first." >&2
  exit 1
fi
exit 0
EOF

cat > .githooks/pre-push <<EOF
#!/bin/bash
protected_branch="$branch"

while read -r local_ref local_sha remote_ref remote_sha; do
  if [ "\$remote_ref" = "refs/heads/\$protected_branch" ]; then
    echo "Push to '\$protected_branch' rejected. Merge via a feature branch/PR instead." >&2
    exit 1
  fi
done
exit 0
EOF
chmod +x .githooks/pre-commit .githooks/pre-push

git config core.hooksPath .githooks

# --- 4. CLAUDE.md notes ---
marker="## Main branch protection (Claude Code hook)"
if [ ! -f CLAUDE.md ] || ! grep -qF "$marker" CLAUDE.md; then
  cat >> CLAUDE.md <<EOF

$marker

\`.claude/hooks/block-main-git.sh\`, wired via \`.claude/settings.json\`
(\`PreToolUse\` on the \`Bash\` matcher), blocks \`git commit\` and \`git push\`
run through Claude Code's Bash tool while the current branch is \`$branch\`.

- Agent-side only — it governs Claude Code's Bash tool, not git itself.
- New/edited \`.claude/settings.json\` needs \`/hooks\` (or a fresh session)
  to take effect — the config watcher only tracks directories that
  existed when the session started.

## Main branch protection (real git hooks)

\`.githooks/pre-commit\` and \`.githooks/pre-push\` reject a commit or push
that targets \`$branch\`, checked out via \`core.hooksPath .githooks\`.

- Covers every git client (terminal, editors, CI) — not just Claude Code.
- \`--no-verify\` bypasses either hook by design; convention, not
  enforcement. For hard enforcement, use server-side branch protection
  rules on GitHub/GitLab.
- \`core.hooksPath\` is a per-clone git config, not tracked by git —
  each clone must run \`git config core.hooksPath .githooks\` once.
EOF
fi

echo "Branch protection set up for '$branch'."
echo "Reload hooks with /hooks (or a fresh session) to activate the Claude Code hook."
