#!/usr/bin/env bash
# Validate the Chord marketplace manifest and every plugin manifest with
# the official Claude Code CLI (`claude plugin validate --strict`).
#
# Exits non-zero if any manifest is invalid, so it works as a CI gate and
# as a pre-push check contributors can run by hand:
#
#   ./scripts/validate.sh
#
# It discovers plugins dynamically from plugins/*/, so adding a new plugin
# needs no change here — just a new dir with a .claude-plugin/plugin.json
# and a matching entry in .claude-plugin/marketplace.json.

set -euo pipefail

# Run from the repo root regardless of where the script is invoked.
cd "$(dirname "$0")/.."

if ! command -v claude >/dev/null 2>&1; then
  echo "error: 'claude' CLI not found." >&2
  echo "       install with: npm install -g @anthropic-ai/claude-code" >&2
  exit 127
fi

fail=0

echo "==> marketplace: .claude-plugin/marketplace.json"
claude plugin validate .claude-plugin/marketplace.json --strict || fail=1

shopt -s nullglob
plugins=(plugins/*/)
if [[ ${#plugins[@]} -eq 0 ]]; then
  echo "error: no plugins found under plugins/*/" >&2
  exit 1
fi

for dir in "${plugins[@]}"; do
  name="$(basename "$dir")"
  echo "==> plugin: $name"
  claude plugin validate "$dir" --strict || fail=1
done

if [[ $fail -ne 0 ]]; then
  echo "" >&2
  echo "validation FAILED — one or more manifests are invalid." >&2
  exit 1
fi

echo ""
echo "all manifests valid (${#plugins[@]} plugin(s) + marketplace)"
