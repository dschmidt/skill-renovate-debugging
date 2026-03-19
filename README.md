# skill-renovate-debugging

Debug and test [Renovate](https://github.com/renovatebot/renovate) bot configuration locally using Docker.

## What it does

Runs Renovate in local mode against your repository and provides a structured summary of:

- Config validation status
- Detected package managers and dependency counts
- Proposed version updates
- Warnings and errors
- Custom/regex manager matches

## Requirements

- Docker (running and accessible)
- Git repository with a Renovate config file

## Installation

Add to your Claude Code settings (`~/.claude/settings.json`):

```json
{
  "extraKnownMarketplaces": {
    "skill-renovate-debugging": {
      "source": { "source": "github", "repo": "dschmidt/skill-renovate-debugging" }
    }
  },
  "enabledPlugins": {
    "skill-renovate-debugging@skill-renovate-debugging": true
  }
}
```

## Usage

In any git repository with a Renovate config:

```
/renovate-debugging
```

Or just ask naturally:
- "Test my renovate config"
- "What dependencies does renovate detect?"
- "Why isn't renovate picking up my Docker images?"
- "Check if my custom regex manager works"

## How it works

1. Runs preflight checks (Docker, git repo, config file)
2. Executes Renovate via Docker with `--platform=local` (read-only, no mutations)
3. Filters the verbose debug output into a concise summary
4. Presents findings in a structured format

The full Renovate log is saved to `/tmp/renovate-output.log` for deeper investigation if needed.

The bundled `scripts/run.sh` also works standalone without Claude Code.

## License

MIT
