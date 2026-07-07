# Type Ratchet

[![Marketplace](https://img.shields.io/badge/Marketplace-Type%20Ratchet-2ea44f?logo=github)](https://github.com/marketplace/actions/type-ratchet)
[![Release](https://img.shields.io/github/v/release/motchalini-llc/type-ratchet?sort=semver)](https://github.com/motchalini-llc/type-ratchet/releases)
[![self-test](https://github.com/motchalini-llc/type-ratchet/actions/workflows/self-test.yml/badge.svg)](https://github.com/motchalini-llc/type-ratchet/actions/workflows/self-test.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A zero-dependency GitHub Action that **stops new dynamic types from creeping into a type-checked codebase**.

Your type checker (`mypy --strict`, `tsc`) can pass while escape hatches quietly pile up: `Any`, `# type: ignore`, `any`, `as any`, `@ts-ignore`. Type Ratchet counts those escape hatches and **fails the PR if the count goes up** — so a clean codebase stays clean, and a messy one only gets better (a ratchet).

It does **not** just rerun your type checker. It catches the thing type checkers can't: someone silencing the checker instead of fixing the type.

**Why now:** AI coding agents are very good at making CI green — and the fastest route to green is `as any`, not a fix. A reviewer can miss one escape hatch in a 400-line diff; a counter can't. No AI, no SaaS, no config: the whole gate is [one bash script](gate.sh) you can read.

> 📖 Launch article: [Your AI makes CI green by cheating. I built three GitHub Actions to stop it.](https://dev.to/motchalini/your-ai-makes-ci-green-by-cheating-i-built-three-github-actions-to-stop-it-4pal) · [日本語版 (Zenn)](https://zenn.dev/motchalini/articles/99f743d923fb54)

[![Demo: one 'quick fix' PR trips all three ratchet gates](https://raw.githubusercontent.com/motchalini-llc/ratchet-demo/main/docs/ratchet-demo.gif)](https://github.com/motchalini-llc/ratchet-demo/pull/1)

> 🔴 **Live demo:** [ratchet-demo#1](https://github.com/motchalini-llc/ratchet-demo/pull/1) — one "quick fix" PR that silences the type checker, skips a test and mutes the linter. All three gates go red with inline annotations.

## The Ratchet family

Three zero-dependency PR gates, each blocking a different way a green check gets faked:

| Action | Blocks the cheat |
|---|---|
| [Type Ratchet](https://github.com/marketplace/actions/type-ratchet) **← this repo** | type escape hatches — `any` / `as any` / `# type: ignore` |
| [Test Ratchet](https://github.com/marketplace/actions/test-ratchet) | disabled tests — `it.skip` / `.only` / `@pytest.mark.skip` |
| [Suppress Ratchet](https://github.com/marketplace/actions/suppress-ratchet) | linter suppressions — `eslint-disable` / `biome-ignore` / `# noqa` |

## Usage

Add one step to a PR workflow:

```yaml
# .github/workflows/type-ratchet.yml
name: Type Ratchet Gate
on:
  pull_request:
    branches: [main]
jobs:
  gate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: motchalini-llc/type-ratchet@v1
        with:
          language: typescript   # python | typescript | auto
```

### TypeScript (with type check)

```yaml
      - uses: actions/checkout@v4
      - run: corepack enable
      - run: pnpm install --frozen-lockfile
      - uses: motchalini-llc/type-ratchet@v1
        with:
          language: typescript
          typecheck-command: pnpm exec tsc --noEmit
```

### Python (with mypy)

```yaml
      - uses: actions/checkout@v4
      - uses: astral-sh/setup-uv@v5
      - run: uv sync --frozen
      - uses: motchalini-llc/type-ratchet@v1
        with:
          language: python
          baseline-any: '5'        # legitimate Any left in the code (e.g. pd.Series[Any])
          baseline-suppress: '2'
          typecheck-command: uv run mypy src
```

## Inputs

| Input | Default | Description |
|---|---|---|
| `language` | `auto` | `python` \| `typescript` \| `auto` (detects from `pyproject.toml` / `tsconfig.json`) |
| `paths` | `src` | Space-separated directories to scan |
| `baseline-any` | `0` | Max allowed dynamic-type count (`Any` / `any`) |
| `baseline-suppress` | `0` | Max allowed suppression count (`type: ignore` / `as any` / `@ts-ignore`) |
| `baseline-file` | `''` | Optional file defining `ANY_BASELINE` / `SUP_BASELINE` (overrides the numeric inputs) |
| `typecheck-command` | `''` | Optional command also run as part of the gate (e.g. `pnpm exec tsc --noEmit`) |
| `working-directory` | `.` | Directory to run in |

## What counts

| | dynamic type | suppression |
|---|---|---|
| **Python** | `Any` | `# type: ignore` |
| **TypeScript** | `any` (type position) | `as any`, `@ts-ignore`, `@ts-expect-error` |

TypeScript test files (`*.test.ts(x)`, `*.spec.ts(x)`) are excluded from the count, so tests can use pragmatic `as any` for mocks. Keep them type-checked / run via `typecheck-command`.

## Output

On failure the action:

- Emits **inline annotations** (`::error`) on the exact offending lines, so violations show up right on the PR's *Files changed* tab.
- Writes a **job summary** table (counts vs. baseline per metric) to the run summary.

## Tightening the ratchet

When you remove escape hatches and the count drops below the baseline, the gate prints `IMPROVED` — lower the baseline and commit it. The count can only go down.

## License

MIT
