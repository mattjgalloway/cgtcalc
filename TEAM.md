# cgtcalc Team

## Project Snapshot

`cgtcalc` is a rule-focused UK capital gains calculator implemented as:
- a core library target (`CGTCalcCore`) containing tax logic
- a thin CLI target (`cgtcalc`) handling input/output orchestration

The codebase emphasizes explicit rule implementation, predictable behavior, and testability over abstraction-heavy design.

## Working Model

### Architect

Owns:
- keeping architecture small, explicit, and coherent
- maintaining boundaries between parser, calculator, and formatter
- ensuring docs track actual behavior

### Coder

Owns:
- implementing and refactoring tax rules in focused units
- preserving deterministic behavior and clear failure modes
- keeping fixtures and tests aligned with semantic intent

### Tester / Tax Reviewer

Owns:
- validating behavior against realistic scenarios
- identifying edge-case arithmetic and chronology issues
- driving fixes into focused tests and fixtures

## Engineering Rules

- Use `Decimal` for monetary and quantity calculations.
- Favor focused units and direct tests over broad integration-only coverage.
- Keep CLI I/O thin and keep business logic in `CGTCalcCore`.
- Keep production functions documented with short `///` comments.
- Run `swiftformat .` and `swift test` as part of normal change flow.

## Supported Behavior (Current)

- same-day matching and same-day disposal merging
- 30-day-after matching
- Section 104 pooled matching
- `SPLIT` / `UNSPLIT` support across matching paths
- `CAPRETURN` and `DIVIDEND` support with current semantics
- grouped same-day distribution amount validation
- oversell rejection with explicit errors
- stable report output via `TextReportFormatter` (all platforms) and `PDFReportFormatter` (macOS)
- golden fixture verification and formatter-focused tests

## Intentional Non-Coverage

The team currently treats these as out of scope:
- UI products and workflow layers
- filing integrations and tax-submission automation
- persistence, syncing, and external service integrations
- full tax-payable modeling that depends on taxpayer income-band context
- broader non-share/non-fund asset class regimes
- currency conversion / FX-rate lookup behavior
- mixed-currency accounting (inputs must be in GBP)

## Current Improvement Focus

- strengthen invalid-input fixture coverage
- expand formatter-focused output tests
- improve special-year tax-return presentation clarity
- keep documentation and tests tightly synchronized with behavior
