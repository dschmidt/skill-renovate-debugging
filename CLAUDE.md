# skill-renovate-debugging

Claude Code skill plugin for debugging Renovate bot configuration locally via Docker.

## Key technical context

- `scripts/run.sh` handles Docker invocation + output filtering (Claude sees ~50-100 lines, not 4000+)
- Full log at `/tmp/renovate-output.log` for targeted follow-up
- Docker mount: repo at `/usr/src/app` (NOT `/repo`), cache at `/tmp/renovate/cache` (avoids EACCES)
- Renovate uses `git ls-files` for file discovery (untracked files missed) but reads content from filesystem (uncommitted edits visible)
- `--platform=local` makes Renovate read-only — no branches, no PRs

## Structure

```
.claude-plugin/marketplace.json    # Plugin manifest (name: skill-renovate-debugging)
skills/renovate-debugging/
  SKILL.md                         # Main skill instructions
  references/reference.md          # Troubleshooting, mount paths, grep patterns
  scripts/run.sh                   # Docker invocation + output filtering (standalone-capable)
README.md
LICENSE                            # MIT
```
