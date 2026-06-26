#!/usr/bin/env bash
# 型ラチェットの検証ゲート（言語非依存・依存ゼロ）。
#
# 型チェックが通った状態から、逃げ道の動的型を「増やさない」ことを保証する。
#   Python:     Any        / type: ignore
#   TypeScript: any(型位置) / as any・@ts-ignore・@ts-expect-error
#
# 入力は INPUT_* 環境変数（action.yml が設定）。ローカルでも同じ env で実行可能。
set -uo pipefail

cd "${INPUT_WORKING_DIRECTORY:-.}"

LANGUAGE="${INPUT_LANGUAGE:-auto}"
if [ "$LANGUAGE" = "auto" ]; then
  if [ -f pyproject.toml ] || [ -f setup.cfg ] || [ -f mypy.ini ] || [ -f setup.py ]; then
    LANGUAGE=python
  elif [ -f tsconfig.json ] || [ -f package.json ]; then
    LANGUAGE=typescript
  else
    echo "言語を自動検出できません。language を python / typescript で指定してください。" >&2
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
    # テストは part-mock 用の any を許容（型検査・実行は別途 typecheck-command で担保）
    EXCLUDES=(--exclude="*.test.ts" --exclude="*.test.tsx"
              --exclude="*.spec.ts" --exclude="*.spec.tsx")
    ANY_PAT='(:|<|\|)[[:space:]]*any\b|\bany\[\]'
    SUP_PAT='\bas any\b|@ts-(ignore|expect-error)'
    ANY_LABEL="any"
    ;;
  *)
    echo "未知の language: $LANGUAGE" >&2
    exit 2
    ;;
esac

# baseline: 入力値を既定とし、baseline-file があれば上書き（ANY_BASELINE/SUP_BASELINE）。
ANY_BASELINE="${INPUT_BASELINE_ANY:-0}"
SUP_BASELINE="${INPUT_BASELINE_SUPPRESS:-0}"
if [ -n "${INPUT_BASELINE_FILE:-}" ] && [ -f "${INPUT_BASELINE_FILE}" ]; then
  # shellcheck disable=SC1090
  source "${INPUT_BASELINE_FILE}"
fi

read -ra PATHS <<< "${INPUT_PATHS:-src}"

# grep は0件時 exit 1（pipefail で死ぬ）ため { ...; || true; } で吸収して wc で数える。
count() {
  { grep -rnIE "${INCLUDES[@]}" "${EXCLUDES[@]}" "$1" "${PATHS[@]}" || true; } | wc -l | tr -d ' '
}
show() {
  grep -rnIE "${INCLUDES[@]}" "${EXCLUDES[@]}" "$1" "${PATHS[@]}" || true
}

ANY_NOW=$(count "$ANY_PAT")
SUP_NOW=$(count "$SUP_PAT")

echo "language=${LANGUAGE}  paths=${PATHS[*]}"
echo "${ANY_LABEL}:        now=${ANY_NOW}  baseline=${ANY_BASELINE}"
echo "suppress:   now=${SUP_NOW}  baseline=${SUP_BASELINE}"

status=0
if [ "$ANY_NOW" -gt "$ANY_BASELINE" ]; then
  echo "❌ REGRESSION: ${ANY_LABEL} が増えた (${ANY_NOW} > ${ANY_BASELINE})"
  show "$ANY_PAT"
  status=1
fi
if [ "$SUP_NOW" -gt "$SUP_BASELINE" ]; then
  echo "❌ REGRESSION: suppression が増えた (${SUP_NOW} > ${SUP_BASELINE})"
  show "$SUP_PAT"
  status=1
fi
if [ "$status" -eq 0 ]; then
  if [ "$ANY_NOW" -lt "$ANY_BASELINE" ] || [ "$SUP_NOW" -lt "$SUP_BASELINE" ]; then
    echo "✅ IMPROVED: baseline より下回った。baseline を更新してラチェットを締めよ。"
  else
    echo "✅ HELD: baseline を維持。"
  fi
fi

# 任意: 型チェック等のコマンドも実行（例 "pnpm exec tsc --noEmit" / "uv run mypy src"）。
if [ -n "${INPUT_TYPECHECK_COMMAND:-}" ]; then
  echo "--- typecheck: ${INPUT_TYPECHECK_COMMAND} ---"
  bash -c "${INPUT_TYPECHECK_COMMAND}" || status=1
fi

exit "$status"
