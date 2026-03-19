# Renovate Local Testing Reference

## Docker Mount Paths

The Docker command mounts the repo at `/usr/src/app`. This is critical — Renovate's local mode expects the repo at this path, NOT `/repo` (which is for self-hosted server mode).

```bash
-v "$(git rev-parse --show-toplevel):/usr/src/app"
```

The cache directory must be at `/tmp/renovate/cache` inside the container. Mounting to other paths (like `/tmp/cache`) causes EACCES permission errors because the Renovate container runs as a non-root user.

```bash
-v "/tmp/renovate-cache:/tmp/renovate/cache"
```

## Dry-Run Modes

Renovate supports different dry-run modes via the `RENOVATE_DRY_RUN` env var:

| Mode | Behavior |
|------|----------|
| `lookup` | Finds updates but doesn't create branches/PRs. Fastest. |
| `full` | Simulates everything including branch creation logic, but doesn't push. |
| (not set) | In local mode (`--platform=local`), Renovate already runs in a read-only fashion — it won't push or create PRs. |

For local testing, you generally don't need to set `RENOVATE_DRY_RUN` because `--platform=local` already prevents any mutations. The dry-run modes are more relevant for testing against real GitHub/GitLab platforms.

## Log Level

Set via the `LOG_LEVEL` env var:

| Level | Lines (typical) | Use case |
|-------|-----------------|----------|
| `debug` | 3000-5000+ | Full visibility, see every file scan and regex match |
| `info` | 500-1000 | Manager summaries, update decisions |
| `warn` | 10-50 | Only problems |

Default is `debug` for maximum diagnostic value.

## Key Grep Patterns

These patterns help extract specific information from Renovate debug output:

### Config validation
```
grep -E "(Invalid|config-validation|WARN.*config)" /tmp/renovate-output.log
```

### Manager detection and dependency counts
```
awk '/^DEBUG: packageFiles with updates/{found=1; next} found && /^[A-Z]/{exit} found{sub(/^       "config": /, ""); print}' /tmp/renovate-output.log \
  | jq -r 'to_entries[] | "\(.key): \(.value | length) files, \(.value | [.[].deps | length] | add) deps, \(.value | [.[].deps[] | select(.updates | length > 0)] | length) updates"'
```

### Proposed updates (dependency, current version, new version, branch)
```
awk '/^DEBUG: packageFiles with updates/{found=1; next} found && /^[A-Z]/{exit} found{sub(/^       "config": /, ""); print}' /tmp/renovate-output.log \
  | jq -r 'to_entries[] | .value[] | .deps[] | select(.updates | length > 0) | . as $dep | .updates[] | [$dep.depName, ($dep.currentVersion // $dep.currentValue), (.newVersion // .newValue), .branchName] | @tsv' \
  | sort -u
```

### Warnings and errors
```
grep -E '"(WARN|ERROR)"' /tmp/renovate-output.log
```

### Custom regex manager matches
```
grep -E "(customManagers|regex|regexManagers|Custom manager)" /tmp/renovate-output.log
```

## Private Registry Tokens

For repos that pull from private registries (npm, Docker, etc.), Renovate needs authentication tokens. Pass them as env vars:

```bash
docker run --rm \
  -e RENOVATE_TOKEN="..." \
  -e NPM_TOKEN="..." \
  -e DOCKER_USERNAME="..." \
  -e DOCKER_PASSWORD="..." \
  ...
```

Or mount a `config.js` file with `hostRules`:

```js
module.exports = {
  hostRules: [
    {
      matchHost: "registry.example.com",
      token: process.env.REGISTRY_TOKEN
    }
  ]
};
```

## Common Pitfalls

### Untracked files not discovered
In local mode, Renovate uses `git ls-files` to discover files. Brand-new files that haven't been `git add`ed won't be found. Modifications to already-tracked files are visible immediately (read from the mounted filesystem). If a new file isn't being detected, `git add` it first.

### Cache corruption
If Renovate fails with obscure errors about lookups or network, try clearing the cache:
```bash
rm -rf /tmp/renovate-cache
```

### ARM architecture (Apple Silicon)
The `renovate/renovate:latest` image is multi-arch, but some operations may be slower on ARM. If Docker is running under Rosetta emulation, builds can be significantly slower. No functional issues though.

### Container already running
If a previous Renovate run was killed mid-execution, the cache directory may have lock files. Clear with:
```bash
rm -rf /tmp/renovate-cache
```

### Very large repos
For monorepos with hundreds of packages, Renovate's debug output can exceed 10,000 lines. Use `info` log level to reduce noise, or rely on the filtered summary from `run.sh`.

### File not detected by expected manager
If a file isn't being picked up by the expected manager:
1. Check if the file is tracked by git (`git ls-files <file>` — empty output means untracked)
2. Check if the file matches the manager's default file patterns
3. Check `renovate.json` for `ignorePaths` or `includePaths` that might exclude it
4. Search the debug log for the filename to see if Renovate found but skipped it
