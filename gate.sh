#!/usr/bin/env bash
# Type Ratchet gate (language-agnostic, zero-dependency).
#
# Given a codebase that already type-checks, this ensures the escape hatches
# do not increase:
#   Python:     Any        / type: ignore
#   TypeScript: any (type position) / as any / @ts-ignore / @ts-expect-error
#
# Inputs come from INPUT_* env vars (set by action.yml). Runs locally with the
# same env.
set -uo pipefail

cd "${INPUT_WORKING_DIRECTORY:-.}"

# GitHub inline annotations (::error) need paths relative to the repo root, so
# prefix offending paths when working-directory is not ".".
ANNOT_PREFIX=""
[ "${INPUT_WORKING_DIRECTORY:-.}" != "." ] && ANNOT_PREFIX="${INPUT_WORKING_DIRECTORY%/}/"

LANGUAGE="${INPUT_LANGUAGE:-auto}"
if [ "$LANGUAGE" = "auto" ]; then
  if [ -f pyproject.toml ] || [ -f setup.cfg ] || [ -f mypy.ini ] || [ -f setup.py ]; then
    LANGUAGE=python
  elif [ -f tsconfig.json ] || [ -f package.json ]; then
    LANGUAGE=typescript
  else
    echo "Could not auto-detect language. Set 'language' to python or typescript." >&2
    exit 2
  fi
fi

case "$LANGUAGE" in
  python)
    INCLUDES=(--include="*.py")
    EXCLUDES=()
    ANY_PAT='\bAny\b'
    SUP_PAT='type: *ignore'
    ANY_LABEL="Any"
    ;;
  typescript)
    INCLUDES=(--include="*.ts" --include="*.tsx")
    # Tests may use pragmatic any for mocks; type-check/run them via typecheck-command instead.
    EXCLUDES=(--exclude="*.test.ts" --exclude="*.test.tsx"
              --exclude="*.spec.ts" --exclude="*.spec.tsx")
    ANY_PAT='(:|<|\|)[[:space:]]*any\b|\bany\[\]'
    SUP_PAT='\bas any\b|@ts-(ignore|expect-error)'
    ANY_LABEL="any"
    ;;
  *)
    echo "Unknown language: $LANGUAGE" >&2
    exit 2
    ;;
esac

# Baseline: numeric inputs are the default; baseline-file overrides them
# (ANY_BASELINE / SUP_BASELINE).
ANY_BASELINE="${INPUT_BASELINE_ANY:-0}"
SUP_BASELINE="${INPUT_BASELINE_SUPPRESS:-0}"
if [ -n "${INPUT_BASELINE_FILE:-}" ] && [ -f "${INPUT_BASELINE_FILE}" ]; then
  # shellcheck disable=SC1090
  source "${INPUT_BASELINE_FILE}"
fi

read -ra PATHS <<< "${INPUT_PATHS:-src}"

# grep exits 1 on zero matches (fatal under pipefail), so wrap with { ...; || true; }
# and count lines with wc.
count() {
  { grep -rnIE "${INCLUDES[@]}" "${EXCLUDES[@]}" "$1" "${PATHS[@]}" || true; } | wc -l | tr -d ' '
}
# List offending locations and emit GitHub Actions inline annotations (::error).
report() {
  local pat="$1" kind="$2" m file line
  while IFS= read -r m; do
    [ -n "$m" ] || continue
    file="${m%%:*}"
    line="$(printf '%s' "$m" | cut -d: -f2)"
    echo "  ${ANNOT_PREFIX}${file}:${line}"
    echo "::error file=${ANNOT_PREFIX}${file},line=${line}::Type Ratchet: new ${kind} not allowed (exceeds baseline)"
  done < <(grep -rnIE "${INCLUDES[@]}" "${EXCLUDES[@]}" "$pat" "${PATHS[@]}" 2>/dev/null || true)
}

# Write a results table to the job summary if GITHUB_STEP_SUMMARY is set.
write_summary() {
  [ -n "${GITHUB_STEP_SUMMARY:-}" ] || return 0
  local a s
  [ "$ANY_NOW" -gt "$ANY_BASELINE" ] && a="❌ regression" || a="✅"
  [ "$SUP_NOW" -gt "$SUP_BASELINE" ] && s="❌ regression" || s="✅"
  {
    echo "## Type Ratchet"
    echo ""
    echo "| metric | now | baseline | status |"
    echo "|---|---|---|---|"
    echo "| ${ANY_LABEL} | ${ANY_NOW} | ${ANY_BASELINE} | ${a} |"
    echo "| suppression | ${SUP_NOW} | ${SUP_BASELINE} | ${s} |"
    echo ""
    echo "language \`${LANGUAGE}\` · paths \`${PATHS[*]}\`"
  } >> "$GITHUB_STEP_SUMMARY"
}

ANY_NOW=$(count "$ANY_PAT")
SUP_NOW=$(count "$SUP_PAT")

echo "language=${LANGUAGE}  paths=${PATHS[*]}"
echo "${ANY_LABEL}:        now=${ANY_NOW}  baseline=${ANY_BASELINE}"
echo "suppress:   now=${SUP_NOW}  baseline=${SUP_BASELINE}"

status=0
if [ "$ANY_NOW" -gt "$ANY_BASELINE" ]; then
  echo "❌ REGRESSION: ${ANY_LABEL} increased (${ANY_NOW} > ${ANY_BASELINE})"
  report "$ANY_PAT" "${ANY_LABEL}"
  status=1
fi
if [ "$SUP_NOW" -gt "$SUP_BASELINE" ]; then
  echo "❌ REGRESSION: suppression increased (${SUP_NOW} > ${SUP_BASELINE})"
  report "$SUP_PAT" "suppression"
  status=1
fi
if [ "$status" -eq 0 ]; then
  if [ "$ANY_NOW" -lt "$ANY_BASELINE" ] || [ "$SUP_NOW" -lt "$SUP_BASELINE" ]; then
    echo "✅ IMPROVED: below baseline — lower the baseline to tighten the ratchet."
  else
    echo "✅ HELD: at baseline."
  fi
fi

write_summary

# Optional: also run a type-check command (e.g. "pnpm exec tsc --noEmit" / "uv run mypy src").
if [ -n "${INPUT_TYPECHECK_COMMAND:-}" ]; then
  echo "--- typecheck: ${INPUT_TYPECHECK_COMMAND} ---"
  bash -c "${INPUT_TYPECHECK_COMMAND}" || status=1
fi

exit "$status"
