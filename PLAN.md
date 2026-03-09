# cgtcalc Plan

## Current State

`cgtcalc` is a Swift CLI for UK share/fund disposal matching and gain/loss reporting.

The project currently provides:
- same-day disposal merging for same asset/date before rounding
- same-day and 30-day-after matching
- Section 104 pooled matching for remaining quantity
- `SPLIT`, `UNSPLIT`, and exact-ratio `RESTRUCT` handling in both B&B and Section 104 paths
- `CAPRETURN` and `DIVIDEND` cost-basis adjustments
- grouped same-day validation for distribution amounts
- explicit oversell errors
- deterministic report output with tax-year summaries, disposal detail, tax-return info, holdings, and input-order transaction/event sections
- pluggable report formatting (`text` on all platforms, `pdf` on macOS)

## Current Priorities

1. Keep rule behavior explicit and well-tested at the correct layer.
2. Keep parser validation structural and chronology-dependent validation in calculator units.
3. Keep output formatting aligned with engine behavior and model semantics.
4. Keep docs and tests synchronized with code.

## Intentional Boundaries

This project intentionally does not currently cover:
- GUI workflows
- persistence/database layers
- network integrations
- self-assessment filing integrations
- a full UK tax-payable model based on income-band usage
- advanced asset classes and edge regimes outside the current supported share/fund assumptions
- currency conversion / FX-rate handling
- mixed-currency inputs (all monetary inputs are expected to already be GBP)

## Quality Expectations

- Use `Decimal`, not `Double`, for money and quantities.
- Run `swiftformat .` after edits and before tests/commits.
- Run `swift test` before finalizing changes.
- Add focused unit tests when changing focused components.
- Keep function-level `///` docs current on production paths.

## Improvement Backlog

### High Value

- Expand invalid-input fixtures for parser and calculator failures.
- Add more output-focused tests for tax-return detail and holdings edge cases.
- Improve treatment and presentation of special-year rate-change scenarios in tax-return information.

### Medium Value

- Reassess parser/calculator validation boundary for additional structural checks.
- Improve explicitness of user-facing error message stability and documentation.
- Continue tightening formatter tests for mixed matching scenarios and explanation text.

### Ongoing

- Maintain documentation alignment across `ARCHITECTURE.md`, `PLAN.md`, and `TEAM.md`.
- Keep end-to-end fixtures and focused tests representative of real portfolio scenarios.
