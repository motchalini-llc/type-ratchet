# Roadmap

Guiding principle: **ship the light, free version first; build the heavy version only once there's demand.** The gate (counting escape hatches and failing the PR) is the core value — everything else is demand-driven.

## Shipped

- v1 gate: Python (`Any` / `# type: ignore`) and TypeScript (`any` / `as any` / `@ts-ignore`), auto-detected
- Baseline ratchet (count can only go down), `baseline-file` support
- Inline PR annotations + job summary table
- Optional `typecheck-command` (run `tsc` / `mypy` alongside the gate)
- Self-test on fixtures; published to GitHub Marketplace (v1.1.x)

## Next (when there's a clear signal)

- **Demo GIF in the README** — show a PR going red with annotations, then green after a fix. (Cheap, lifts conversion. Do this early.)
- **`mode: fix` (autofix, heavy version)** — open a PR that fixes newly introduced escape hatches.
  - Opt-in only; requires the user's own LLM API key. Hard iteration cap + cost guardrails.
  - Build only after users actually ask for "fix it for me."
- **More precise detection (opt-in)** — for TypeScript, optionally back the count with ESLint `@typescript-eslint/no-explicit-any` to avoid comment/string false positives.

## Ideas backlog

- Per-path / per-package baselines (monorepos).
- A config file (`.type-ratchet.yml`) as an alternative to action inputs.
- More languages (e.g. Kotlin `Any`, C# `dynamic`) if requested.
- `warn-only` mode (annotate without failing) for gradual adoption.
- Auto-suggest lowering the baseline when the count drops (IMPROVED state).

## Later / business

- Marketplace verified publisher (requires the org) once monetizing.
- Decide free vs. paid tiers based on usage and requests.

## Non-goals

- Re-running the type checker for you (that's your existing CI's job; this catches what the type checker *can't*: silencing vs. fixing).
- Becoming a general linter.

## How to validate / what to watch

Marketplace views, stars, issues, and "I tried it" mentions. Issues are the best signal for what to build next.
