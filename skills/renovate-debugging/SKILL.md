---
name: renovate-debugging
description: Run Renovate bot locally via Docker to test and validate Renovate configuration. Simple rule -- if the user mentions "renovate" and the answer requires actually executing Renovate to find out, use this skill. Covers testing renovate config, checking what dependencies renovate detects, verifying custom managers work, previewing what PRs renovate would create, debugging unexpected renovate behavior, and validating config changes before pushing. Even casual questions like "does renovate pick up my docker images", "test my renovate config", or "what will renovate do" should trigger this skill. Not for authoring new renovate configs from scratch, reviewing existing renovate PRs, or fixing CI pipeline issues unrelated to renovate config.
---

# Renovate Local Testing

Test Renovate bot configuration locally using Docker. This skill runs Renovate in local-only mode against the current repository and provides a structured analysis of what Renovate detects and would do.

## Workflow

### Step 1: Run Renovate via the bundled script

Run the bundled helper script that handles Docker invocation and output filtering:

```bash
bash <skill-path>/scripts/run.sh [LOG_LEVEL] [--full] [-e KEY=VALUE ...]
```

- Default log level is `debug` (most complete output)
- Use `--full` only if the user explicitly wants raw unfiltered output
- Use `-e KEY=VALUE` to pass extra env vars to Docker (e.g. private registry tokens: `-e NPM_TOKEN=xxx`)
- The script saves full output to `/tmp/renovate-output.log` and prints a filtered summary to stdout

The summary that comes back is already condensed (~50-100 lines). Read it and proceed to analysis.

### Step 2: Analyze and Report

Present findings to the user in this structure:

**Config Status**: Did Renovate validate the config successfully? Any warnings or errors?

**Detected Managers**: Which package managers did Renovate find? (npm, docker-compose, dockerfile, woodpecker, regex, etc.) How many dependencies per manager?

**Proposed Updates**: What branches would Renovate create? List dependency name, current version, and new version.

**Warnings & Errors**: Any WARN or ERROR lines that indicate problems.

**Custom Managers** *(only if the Renovate config contains `customManagers`/`regexManagers` or the summary mentions custom/regex manager activity)*: Did the custom regex managers match? How many deps did they find? Skip this section entirely if neither the config nor the output references custom managers.

If the user asks for more detail on any section, use Grep or Read on `/tmp/renovate-output.log` to find the relevant lines. The full log can be very large (4000+ lines at debug level), so always search targeted rather than reading the whole thing.

### Common follow-up tasks

- **"Why isn't Renovate finding X?"** — Grep the full log for the package name or file path. Check if the relevant manager ran. Check if the file is tracked by git (`git ls-files <file>`) — Renovate uses `git ls-files` for file discovery, so untracked files won't be found.
- **"What regex pattern should I use?"** — Read `references/reference.md` for regex manager patterns and examples.
- **"Test with a different log level"** — Rerun with `info` or `warn` to reduce noise.

## Important: File discovery vs. file content

In local mode with a volume mount, Renovate reads file **content** directly from the filesystem — so modifications to existing tracked files (like editing `renovate.json`) are visible immediately without committing. However, Renovate uses `git ls-files` to **discover** which files to scan. This means brand-new files that haven't been `git add`ed yet may not be found. If the user added a new Dockerfile or docker-compose file and Renovate doesn't see it, suggest running `git add <file>` first.

## Reference

For troubleshooting, Docker mount details, dry-run modes, private registry tokens, and common pitfalls, read `references/reference.md`.
