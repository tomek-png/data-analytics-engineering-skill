#!/usr/bin/env bash
# Verifies the required skill file structure before publishing.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL_DIR="$ROOT/.agents/skills/data-analytics-engineering"
FAILED=0

fail() { echo "FAIL: $1"; FAILED=1; }
ok()   { echo "ok:   $1"; }

REQUIRED=(
  "SKILL.md"
  "references/tracking-datalayer.md"
  "references/martech-integrations.md"
  "references/data-preparation.md"
  "references/data-quality.md"
  "references/analysis-patterns.md"
  "references/bi-bigquery-ecosystem.md"
  "references/visualization.md"
  "references/system-drift-and-monitoring.md"
)

for f in "${REQUIRED[@]}"; do
  if [ -s "$SKILL_DIR/$f" ]; then ok "$f"; else fail "missing or empty: $f"; fi
done

for f in README.md LICENSE CONTRIBUTING.md; do
  if [ -s "$ROOT/$f" ]; then ok "$f"; else fail "missing or empty: $f"; fi
done

# Frontmatter checks
if head -1 "$SKILL_DIR/SKILL.md" 2>/dev/null | grep -q '^---$'; then
  ok "SKILL.md frontmatter opens"
else
  fail "SKILL.md must start with a --- frontmatter block"
fi
for key in name description; do
  if grep -qm1 "^$key:" "$SKILL_DIR/SKILL.md" 2>/dev/null; then
    ok "frontmatter: $key"
  else
    fail "frontmatter missing: $key"
  fi
done

# Every reference file must be linked from SKILL.md
for f in "$SKILL_DIR"/references/*.md; do
  base="references/$(basename "$f")"
  if grep -qF "$base" "$SKILL_DIR/SKILL.md"; then
    ok "linked from SKILL.md: $base"
  else
    fail "not referenced in SKILL.md: $base"
  fi
done

if [ "$FAILED" -eq 0 ]; then
  echo "--- structure OK"
else
  echo "--- structure check failed"
fi
exit "$FAILED"
