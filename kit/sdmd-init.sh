#!/usr/bin/env bash
# sdmd-init — Bootstrap the SDMD (Spec-Driven Mobile Development) kit into any project.
# Usage: sdmd-init.sh [target-repo-dir]   (defaults to current directory)
# Idempotent: safe to run multiple times. Never overwrites existing files.

set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
TARGET_DIR="${1:-$PWD}"

if [ ! -d "$TARGET_DIR/.git" ] && [ ! -d "$TARGET_DIR" ]; then
  echo "ERROR: '$TARGET_DIR' is not a directory" >&2
  exit 1
fi

TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"
echo "SDMD init -> $TARGET_DIR"
echo "Kit source -> $SOURCE_DIR"

# --- Mobile sanity check (warn only, never block) ---
if ! ls "$TARGET_DIR"/{app,composeApp,iosApp,package.json,pubspec.yaml,app.json} >/dev/null 2>&1 \
   && ! find "$TARGET_DIR" -maxdepth 2 -name "build.gradle.kts" -o -maxdepth 2 -name "Podfile" 2>/dev/null | grep -q .; then
  echo "WARN: no mobile project signals detected (gradle/iosApp/package.json/pubspec). Continuing anyway."
fi

# --- 1. Copy course docs (templates + rules), never overwrite ---
DOCS_SRC="$SOURCE_DIR/docs"
DOCS_DST="$TARGET_DIR/docs"
mkdir -p "$DOCS_DST/features"
COPIED=0
SKIPPED=0
for f in SPEC_TEMPLATE.md PLAN_TEMPLATE.md MOBILE_GUIDELINES.md GENERIC_RULES.md PROMPTS.md; do
  if [ -f "$DOCS_DST/$f" ]; then
    SKIPPED=$((SKIPPED + 1))
  elif [ -f "$DOCS_SRC/$f" ]; then
    cp "$DOCS_SRC/$f" "$DOCS_DST/$f"
    COPIED=$((COPIED + 1))
  fi
done
echo "docs/: $COPIED copied, $SKIPPED already present. Feature docs go in docs/features/<feature>/{SPEC,PLAN,TASKS}.md"

# --- 2. AGENTS.md: create or append the SDMD workflow section (idempotent) ---
AGENTS="$TARGET_DIR/AGENTS.md"
MARKER="<!-- sdmd-workflow -->"
SECTION="$MARKER
## SDMD workflow (Spec-Driven Mobile Development)

Before planning, reviewing, or modifying this project, read docs/GENERIC_RULES.md
in full and docs/MOBILE_GUIDELINES.md when writing or reviewing specs and plans.

Spec-driven flow, gated by EXPLICIT user approval at each stage — a complete
document is not an approved one, and the agent never changes approval states:

1. **SPEC**: fill docs/features/<feature>/SPEC.md from docs/SPEC_TEMPLATE.md,
   collaboratively, section by section. RF- requirements, CA- acceptance criteria.
2. **PLAN**: docs/features/<feature>/PLAN.md from docs/PLAN_TEMPLATE.md, only
   after the spec is approved.
3. **TASKS**: derive docs/features/<feature>/TASKS.md from the approved plan:
   small, ordered, verifiable checkboxes with dependencies and validation method.
4. **Implementation**: only within agreed scope, only after explicit authorization.
5. **Validation**: verify every acceptance criterion with real evidence (executed
   tests, not test names; screenshots do not prove persistence).

Initial prompt to start a feature: docs/PROMPTS.md
<!-- /sdmd-workflow -->"

if [ ! -f "$AGENTS" ]; then
  printf '# AGENTS.md\n\nAgent instructions for this repository.\n\n%s\n' "$SECTION" > "$AGENTS"
  echo "AGENTS.md: created with SDMD workflow section"
elif grep -q "$MARKER" "$AGENTS"; then
  echo "AGENTS.md: SDMD section already present, skipped"
else
  printf '\n%s\n' "$SECTION" >> "$AGENTS"
  echo "AGENTS.md: SDMD workflow section appended (existing content untouched)"
fi

# --- 3. MobiAI Brain: per-project memory (skip silently if CLI absent) ---
if command -v mobiai >/dev/null 2>&1; then
  if [ -f "$TARGET_DIR/.mobiai/brain/config.json" ]; then
    echo "mobiai brain: already initialized"
  else
    (cd "$TARGET_DIR" && mobiai brain init >/dev/null && mobiai brain scan >/dev/null) \
      && echo "mobiai brain: initialized + stack scanned (.mobiai/brain/)"
  fi
else
  echo "mobiai brain: CLI not found, skipped"
fi

echo "Done. Start your first feature with docs/PROMPTS.md."
