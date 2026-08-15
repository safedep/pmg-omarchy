#!/usr/bin/env bash
# Structural validation for the Omarchy plugin: manifest sanity, entry-point
# files exist, and no symlinks (forbidden in plugin folders). Runs in CI and
# locally. Requires jq.
set -euo pipefail
cd "$(dirname "$0")/.."

fail() { echo "ERROR: $*" >&2; exit 1; }

echo "==> no symlinks (forbidden in plugin folders)"
if find . -path ./.git -prune -o -type l -print | grep -q .; then
  fail "plugin folders must not contain symlinks"
fi

echo "==> manifest.json is valid JSON"
jq -e . manifest.json > /dev/null || fail "manifest.json is not valid JSON"

echo "==> required manifest fields present"
for key in schemaVersion id name version kinds entryPoints; do
  jq -e "has(\"$key\")" manifest.json > /dev/null || fail "manifest missing required field: $key"
done

echo "==> every declared kind has an existing entry-point file"
while read -r kind; do
  # kind is kebab-case (bar-widget); entryPoints keys are camelCase (barWidget).
  key=$(printf '%s' "$kind" | sed -E 's/-([a-z])/\U\1/g')
  file=$(jq -r --arg k "$key" '.entryPoints[$k] // empty' manifest.json)
  [ -n "$file" ] || fail "no entryPoints.$key for declared kind '$kind'"
  [ -f "$file" ] || fail "entry-point file '$file' (kind '$kind') does not exist"
  echo "  $kind -> $file"
done < <(jq -r '.kinds[]' manifest.json)

echo "All structure checks passed."
