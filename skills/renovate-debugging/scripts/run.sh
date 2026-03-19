#!/usr/bin/env bash
#
# run.sh — Run Renovate locally via Docker and produce a filtered summary.
#
# Usage: run.sh [LOG_LEVEL] [--full] [-e KEY=VALUE ...]
#   LOG_LEVEL: debug (default), info, warn
#   --full:    Print raw output instead of filtered summary
#   -e KEY=VALUE: Extra env vars forwarded to Docker (repeatable)
#
set -euo pipefail

LOG_LEVEL="debug"
FULL_OUTPUT=false
EXTRA_ENV=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --full) FULL_OUTPUT=true; shift ;;
    -e) [[ $# -ge 2 ]] || { echo "Error: -e requires a KEY=VALUE argument"; exit 1; }; EXTRA_ENV+=("-e" "$2"); shift 2 ;;
    debug|info|warn) LOG_LEVEL="$1"; shift ;;
    *) echo "Unknown argument: $1"; exit 1 ;;
  esac
done

LOGFILE="/tmp/renovate-output.log"

# --- Preflight checks ---

if ! docker info > /dev/null 2>&1; then
  echo "ERROR: Docker is not running or not accessible."
  echo "Start Docker and try again."
  exit 1
fi

if ! git rev-parse --show-toplevel > /dev/null 2>&1; then
  echo "ERROR: Not inside a git repository."
  exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"

# Check for Renovate config
CONFIG_FOUND=false
for f in renovate.json renovate.json5 .renovaterc .renovaterc.json; do
  if [ -f "$REPO_ROOT/$f" ]; then
    CONFIG_FOUND=true
    echo "Config: $f"
    break
  fi
done

if [ "$CONFIG_FOUND" = false ]; then
  # Check package.json for renovate key
  if [ -f "$REPO_ROOT/package.json" ] && grep -q '"renovate"' "$REPO_ROOT/package.json" 2>/dev/null; then
    CONFIG_FOUND=true
    echo "Config: package.json (renovate key)"
  fi
fi

if [ "$CONFIG_FOUND" = false ]; then
  echo "WARNING: No Renovate config file found. Renovate will use default settings."
fi

# --- Prepare cache ---
# Pre-create cache subdirectories so the non-root container user can write to them.
# Without this, Renovate fails with EACCES when trying to mkdir inside the mount.
mkdir -p /tmp/renovate-cache/containerbase

# --- Run Renovate ---
echo ""
echo "Running Renovate (log level: $LOG_LEVEL)..."
echo "Repository: $REPO_ROOT"
echo ""

docker run --rm \
  -v "$REPO_ROOT:/usr/src/app" \
  -v "/tmp/renovate-cache:/tmp/renovate/cache" \
  -e LOG_LEVEL="$LOG_LEVEL" \
  "${EXTRA_ENV[@]+"${EXTRA_ENV[@]}"}" \
  renovate/renovate:latest \
  --platform=local \
  > "$LOGFILE" 2>&1

DOCKER_EXIT=$?
echo "Done. (exit code: $DOCKER_EXIT)"

if [ "$FULL_OUTPUT" = true ]; then
  cat "$LOGFILE"
  echo ""
  echo "Full output above. Log saved to: $LOGFILE"
  exit $DOCKER_EXIT
fi

# --- Filter and summarize ---
echo ""
echo "============================================"
echo "  RENOVATE TEST SUMMARY"
echo "============================================"
echo ""

# Config validation
echo "--- Config Validation ---"
if grep -qiE "(Invalid|config-validation)" "$LOGFILE"; then
  grep -iE "(Invalid|config-validation)" "$LOGFILE" | head -20
else
  echo "No config validation errors found."
fi
echo ""

# Managers detected
echo "--- Managers & Dependencies ---"
grep -E "Found .* package file" "$LOGFILE" 2>/dev/null | head -30 || true
echo ""

# Proposed updates — show unique branches Renovate would create
echo "--- Proposed Updates (branches) ---"
grep -oE '"branchName": "[^"]+"' "$LOGFILE" 2>/dev/null | sort -u | head -30 || true
if ! grep -qE '"branchName"' "$LOGFILE" 2>/dev/null; then
  echo "No updates proposed."
fi
echo ""

# Warnings
echo "--- Warnings ---"
WARN_COUNT=$(grep -c '"WARN"' "$LOGFILE" 2>/dev/null || true)
WARN_COUNT=${WARN_COUNT:-0}
echo "Total warnings: $WARN_COUNT"
if [ "$WARN_COUNT" -gt 0 ]; then
  grep '"WARN"' "$LOGFILE" 2>/dev/null | head -15
fi
echo ""

# Errors
echo "--- Errors ---"
ERROR_COUNT=$(grep -c '"ERROR"' "$LOGFILE" 2>/dev/null || true)
ERROR_COUNT=${ERROR_COUNT:-0}
echo "Total errors: $ERROR_COUNT"
if [ "$ERROR_COUNT" -gt 0 ]; then
  grep '"ERROR"' "$LOGFILE" 2>/dev/null | head -15
fi
echo ""

# Custom managers
echo "--- Custom/Regex Managers ---"
if grep -qE "(customManagers|regexManagers|Custom manager)" "$LOGFILE" 2>/dev/null; then
  grep -E "(customManagers|regexManagers|Custom manager)" "$LOGFILE" 2>/dev/null | head -10
else
  echo "No custom managers detected."
fi
echo ""

echo "============================================"
echo "Full log: $LOGFILE ($(wc -l < "$LOGFILE") lines)"
echo "============================================"

exit $DOCKER_EXIT
