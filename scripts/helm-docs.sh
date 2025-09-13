#!/usr/bin/env bash
# Generate chart README.md using helm-docs for specific charts only
# Usage:
#   bash scripts/helm-docs.sh <chart-name|chart-path|file-path> [...]
#   bash scripts/helm-docs.sh --all | -a    # run for all charts
#   bash scripts/helm-docs.sh --lint <...>  # after generation, run markdown lint (markdownlint-cli2) on changed READMEs
#
# Behavior:
# - Arguments can be chart names (pangolin), chart directories (charts/pangolin), or files under a chart (e.g., charts/pangolin/values.schema.json).
# - The script maps each argument to the nearest chart root (directory containing Chart.yaml) and runs helm-docs only for those charts.
# - With no args: fails (to enforce per-chart operation) unless --all/-a is specified.
# - In CI (CI=true or GITHUB_ACTIONS=true), missing tools are fatal. Locally they are warnings and the script exits 0.
# - Set VERBOSE=1 to see which charts are processed.

set -euo pipefail

here="$(dirname "$0")"
repo_root="$(cd "$here/.." && pwd)"
cd "$repo_root"

is_ci() { [ "${CI:-}" = "true" ] || [ "${GITHUB_ACTIONS:-}" = "true" ]; }
need() { command -v "$1" >/dev/null 2>&1; }
log() { printf '%s\n' "$*" >&2; }

usage() {
  cat >&2 <<EOF
Usage:
  bash scripts/helm-docs.sh <chart-name|chart-path|file-path> [...]
  bash scripts/helm-docs.sh --all | -a
  bash scripts/helm-docs.sh --lint <args>

Notes:
- Runs helm-docs only for the resolved chart(s).
- Fails if no args are given (enforces per-chart) unless --all/-a is used.
- Accepts multiple args; each is mapped to a chart root.
- Set VERBOSE=1 for debug logging.
EOF
}

ALL=0
DO_LINT=0
ARGS=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    --all|-a)
      ALL=1
      ;;
    --lint)
      DO_LINT=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      ARGS+=("$1")
      ;;
  esac
  shift
done

# Tool checks
if ! need helm-docs; then
  if is_ci; then
    log "[helm-docs.sh] helm-docs is required in CI but not found"
    exit 1
  fi
  log "[helm-docs.sh] helm-docs not found; skipping locally"
  exit 0
fi

if [ "$DO_LINT" -eq 1 ] && ! need markdownlint-cli2; then
  if is_ci; then
    log "[helm-docs.sh] markdownlint-cli2 is required for --lint in CI but not found"
    exit 1
  fi
  log "[helm-docs.sh] markdownlint-cli2 not found; continuing without lint"
  DO_LINT=0
fi

branch() {
  if [ -n "${GITHUB_REF_NAME:-}" ]; then
    printf "%s" "$GITHUB_REF_NAME"
  else
    git rev-parse --abbrev-ref HEAD 2>/dev/null || echo ""
  fi
}

if [ "$(branch)" = "gh-pages" ]; then
  log "[helm-docs.sh] skipping on gh-pages branch"
  exit 0
fi

# Resolve arguments to chart roots
# A chart root is any directory that contains Chart.yaml
is_chart_root() { [ -f "$1/Chart.yaml" ]; }

# Map a path to its chart root by walking up until Chart.yaml is found
path_to_chart_root() {
  local p="$1"
  # Normalize: if it's a file, use its directory
  if [ -f "$p" ]; then p="$(dirname "$p")"; fi
  # If input is just a name like 'pangolin', try charts/<name>
  if [ ! -e "$p" ] && [ -d "charts/$p" ]; then p="charts/$p"; fi
  # Walk upwards
  while [ "$p" != "/" ] && [ "$p" != "." ]; do
    if is_chart_root "$p"; then
      printf '%s\n' "$p"
      return 0
    fi
    p="$(dirname "$p")"
  done
  return 1
}

collect_charts_from_args() {
  if [ ${#ARGS[@]} -eq 0 ]; then
    return 0
  fi
  for a in "${ARGS[@]}"; do
    if cr=$(path_to_chart_root "$a"); then
      printf '%s\n' "$cr"
    else
      log "[helm-docs.sh] could not resolve chart from argument: $a"
      return 1
    fi
  done
}

collect_all_charts() {
  find charts -type f -name Chart.yaml -print0 | xargs -0 -n1 dirname | sort -u
}

# Determine charts to process
CHARTS=""
if [ "$ALL" -eq 1 ]; then
  CHARTS="$(collect_all_charts)"
else
  if [ ${#ARGS[@]} -eq 0 ]; then
    usage
    log "Error: a chart must be specified, or use --all/-a"
    exit 2
  fi
  CHARTS="$(collect_charts_from_args | sort -u)"
fi

if [ -z "$CHARTS" ]; then
  log "[helm-docs.sh] no charts resolved; nothing to do"
  exit 0
fi

status=0
changed_readmes=()

while IFS= read -r chart; do
  [ -z "$chart" ] && continue
  if [ "${VERBOSE:-0}" = "1" ]; then
    log "[helm-docs.sh] processing chart: $chart"
  fi

  # Only run if template exists, otherwise there is nothing to generate from
  if [ ! -f "$chart/README.md.gotmpl" ]; then
    if [ "${VERBOSE:-0}" = "1" ]; then log "[helm-docs.sh] no README.md.gotmpl in $chart, skipping"; fi
    continue
  fi

  # Track README before and after to detect changes (for optional lint)
  before_hash=""
  if [ -f "$chart/README.md" ]; then
    before_hash="$(sha1sum "$chart/README.md" 2>/dev/null | awk '{print $1}')"
  fi

  if ! helm-docs \
      --chart-search-root="$chart" \
      --template-files=README.md.gotmpl \
      --output-file=README.md; then
    status=1
    continue
  fi

  after_hash=""
  if [ -f "$chart/README.md" ]; then
    after_hash="$(sha1sum "$chart/README.md" 2>/dev/null | awk '{print $1}')"
  fi
  if [ "$before_hash" != "$after_hash" ] && [ -n "$after_hash" ]; then
    changed_readmes+=("$chart/README.md")
  fi

done <<EOF
$CHARTS
EOF

# Optional markdown lint on changed READMEs (or all resolved charts if none changed)
if [ "$DO_LINT" -eq 1 ]; then
  if [ ${#changed_readmes[@]} -eq 0 ]; then
    # If nothing changed, lint the resolved charts' READMEs anyway to catch issues
    while IFS= read -r c; do
      [ -f "$c/README.md" ] && changed_readmes+=("$c/README.md")
    done <<EOF
$CHARTS
EOF
  fi
  if [ ${#changed_readmes[@]} -gt 0 ]; then
    if [ "${VERBOSE:-0}" = "1" ]; then
      log "[helm-docs.sh] linting markdown for: ${changed_readmes[*]}"
    fi
    # Use repo markdownlint config if present
    if [ -f .markdownlint.json ]; then
      markdownlint-cli2 --config .markdownlint.json "${changed_readmes[@]}"
    else
      markdownlint-cli2 "${changed_readmes[@]}"
    fi
  fi
fi

exit $status

