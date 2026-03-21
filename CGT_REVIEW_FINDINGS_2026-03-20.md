# CGT Review Findings

Date: 2026-03-20

This note is intended to help an engineer work through the remaining UK CGT correctness issues in the calculator one by one.

Context:

- Review scope was the whole calculator, with focus on UK Capital Gains Tax correctness for post-6 April 2008 share identification, Section 104 pooling, fund equalisation / accumulation distributions, and spouse transfer handling.
- Full automated test suite passed at the time of review.
- The issues below are therefore not "random broken tests"; they are tax or scope gaps that still need explicit handling.

## Recommended Order

1. P1: Post-buy fund adjustments can be double-counted on 30-day matches
2. P2: HMRC's final share-identification stage is missing
3. P2: 30-day matching is treated as unconditional
4. P3: Tax-year table will fail for 2026/2027 disposals

---

## 1. [P1] Post-buy fund adjustments can be double-counted on 30-day matches

### Status Update (2026-03-21)

Fixed in code.

- `BedAndBreakfastMatcher` now bounds post-buy `DIVIDEND`/`CAPRETURN` event offsets to the next outbound date for that asset, rather than applying them unbounded through all future dates.
- `CGTEngine` now passes all outbounds (taxable sells and spouse transfer outs) into matcher reservation/context so outbound ordering remains consistent.
- Added regression coverage in `CalculatorTests`:
  - `testPostBuyDividendIsNotDoubleCountedAcrossThirtyDayAndLaterSection104Disposals`
- Added/validated end-to-end fixture coverage for spouse transfer reservation interaction:
  - `SpouseTransferReservedForLaterSameDaySell`

Files:

- `Sources/CGTCalcCore/Calculator/BedAndBreakfastMatcher.swift`

Relevant code:

- `eventAdjustment(...)`
- current call site passes `through: nil`

### Problem

When a later `DIVIDEND` or `CAPRETURN` is applied to a bed-and-breakfast rebuy, the calculator currently assumes that later event belongs to the matched rebuy quantity for the earlier disposal.

That is not always true.

If the rebuy has effectively been "used up" by an earlier 30-day match, and the taxpayer later still holds shares only because of a later disposal pattern or residual pool position, a subsequent `DIVIDEND` / `CAPRETURN` may belong to the remaining holding instead. In that case, applying the event to the earlier matched rebuy and also leaving it in the final holding double-counts the event.

### Concrete Repro

Input:

```text
BUY 01/01/2020 TEST 100 10 0
SELL 01/06/2020 TEST 50 20 0
BUY 10/06/2020 TEST 50 12 0
SELL 20/06/2020 TEST 50 25 0
DIVIDEND 30/06/2020 TEST 50 100
```

Current calculator output includes:

- first disposal gain = `300`
- second disposal gain = `750`
- final holding = `50 units acquired at GBP12 cost basis`

### Why This Looks Wrong

The calculator adds the `30/06/2020` dividend of `100` to the rebuy matched against the `01/06/2020` disposal:

- matched cost becomes `50 * 12 + 100 = 700`
- first gain becomes `1000 - 700 = 300`

But the same dividend is also still reflected in the remaining holding after the `20/06/2020` disposal, which means the event has effectively been counted twice.

Tax-wise, the cleaner result looks like:

- first disposal gain = `400`
- second disposal gain = `750`
- dividend attaches to the shares actually held on `30/06/2020`

### Engineering Question To Resolve

For a matched rebuy, should later `DIVIDEND` / `CAPRETURN` adjustments only be included:

- until the next outbound on that asset, or
- only while the matched rebuy quantity can still be regarded as the same economic holding, or
- under some explicit "through date" determined by later outbound usage?

The current unconditional `through: nil` looks too broad.

### Suggested Test To Add

Add a failing end-to-end fixture using the exact repro above, so the expected treatment is agreed before changing the matching logic.

---

## 2. [P2] HMRC's final share-identification stage is missing

Files:

- `Sources/CGTCalcCore/Calculator/CGTEngine.swift`
- `README.md`

### Problem

The engine currently supports:

1. same-day matching
2. acquisitions in the following 30 days
3. Section 104 holding

If those do not fully match the disposal, it throws `insufficientShares`.

HMRC guidance goes one step further: if those rules still do not exhaust the shares disposed of, the remainder is matched with later acquisitions, earliest first.

So the calculator and README currently overstate support for the "full range" of current share-identification rules.

### Concrete Repro

Input:

```text
SELL 01/01/2020 TEST 10 10 0
BUY 15/02/2020 TEST 10 3 0
```

Current result:

```text
Error calculating CGT: insufficientShares(...)
```

### Why This Matters

That is not just a UI/documentation issue. It changes whether some valid share-disposal histories can be computed at all.

If the project intentionally does not want to support this final stage, the README should say so clearly and the engine should probably reject such cases with a more explicit unsupported-case message rather than implying an oversell.

If the project does want full HMRC identification support, this stage needs implementing.

### Suggested Decision

Choose one:

1. implement the final later-acquisitions stage, or
2. explicitly narrow scope in README and error messaging

### Suggested Test To Add

Add a fixture for the repro above, either:

- as a valid example if implementing the later-acquisitions stage, or
- as a dedicated invalid/unsupported example with a clearer message if intentionally unsupported

---

## 3. [P2] 30-day matching is treated as unconditional

Files:

- `Sources/CGTCalcCore/Calculator/BedAndBreakfastMatcher.swift`
- `Sources/CGTCalcCore/Parser/InputParser.swift`
- `README.md`

### Problem

The calculator always applies the 30-day rule whenever it sees a qualifying rebuy in the following 30 days.

HMRC guidance qualifies this rule: it applies only if the disposer was UK resident at the time of the acquisition.

The current input model has no way to represent:

- residence status
- changes in residence over time
- capacity differences

So the engine will silently apply the 30-day rule even in cases where HMRC would not.

### Why This Matters

This is a scope-model problem rather than an arithmetic mistake.

For ordinary UK-resident individual users, the current behavior may be fine.
For non-resident or mixed-residence histories, the calculator can produce a result that looks authoritative but is tax-incorrect.

### Suggested Decision

Choose one:

1. explicitly define project scope as UK-resident individual cases only, or
2. extend the input model so the 30-day rule can be conditionally applied

### Suggested Documentation Change

If not implementing residence-aware logic, add an explicit limitation in README such as:

> The 30-day matching logic assumes the disposer is UK resident at the time of the later acquisition.

---

## 4. [P3] Tax-year table will fail for 2026/2027 disposals

Files:

- `Sources/CGTCalcCore/Models/TaxYear.swift`

### Problem

The lookup table currently includes annual exempt amounts up to:

- `2025/2026`

It does not yet include:

- `2026/2027`

As of the review date, HMRC has already published the annual exempt amount as `GBP3,000`.

### Why This Matters

Any disposal on or after `6 April 2026` will throw:

- `missingTaxRates`

This is not a logic flaw in calculations, but it is a user-visible failure waiting to happen.

### Suggested Fix

Add:

```swift
2026: TaxRates(exemption: 3000) // 2026/2027
```

and consider adding a lightweight maintenance reminder test so future years are updated before the relevant tax year starts.

---

## Source Notes

Main HMRC guidance used in review:

- HS284 Shares and Capital Gains Tax
- CG51550 Share identification rules
- HS281 Capital Gains Tax civil partners and spouses
- GOV.UK Capital Gains Tax allowances page

The residence-related point and the final later-acquisitions point both come from HMRC's share-identification guidance.

The post-buy fund-adjustment issue is an inference from:

- the calculator's own event semantics for `DIVIDEND` / `CAPRETURN`
- share identification ordering
- and the observed double-count pattern in the repro above

That issue should be validated with an agreed expected test before changing implementation.

---

## Potential Future Improvements

These are not necessarily current bugs, but they are good candidates for hardening the calculator's CGT correctness and making the scope clearer.

### 1. Narrow and state the scope more explicitly

The calculator currently reads like a general UK CGT calculator for shares, but the practical scope is narrower.

It would help to state something closer to:

- UK-resident individuals
- ordinary shares / fund units
- single beneficial capacity
- post-6 April 2008 acquisition histories
- only scenarios representable by the supported input rows

That would reduce the risk of users assuming support for cases the model cannot currently represent.

### 2. Add explicit unsupported-case messaging

Where the engine currently fails with generic `insufficientShares`, some cases are not true oversells but unsupported identification/model cases.

Examples:

- later-acquisitions matching stage not implemented
- residence-dependent 30-day-rule cases
- any future connected-party / market-value scenarios if not modelled

Clearer errors would make review and user debugging much easier.

### 3. Add more fixtures for tricky fund/event interactions

The fund equalisation / accumulation-distribution logic is one of the calculator's most valuable features, but also one of the easiest areas to drift subtly.

Good additional fixture candidates:

- a 30-day rebuy followed by a later `DIVIDEND`
- a 30-day rebuy followed by a later `CAPRETURN`
- partial later disposal before the post-buy event date
- multiple post-buy event dates across one rebuy lifecycle
- same asset with both Section 104 residual holding and matched rebuy history around the same event date

These would help pin down exactly when a later event should attach to a matched rebuy versus the residual pool.

### 4. Add a maintenance test for tax-year rates

The tax-year table needs periodic updates.

A lightweight test or reminder mechanism could reduce the chance of entering a new tax year with missing allowance data.

Possible approaches:

- a test asserting support through at least the current tax year plus one
- a CI check keyed to the current calendar date
- a simple documented release checklist item

### 5. Consider first-class support for connected-party / deemed-market-value cases

The current transaction model assumes actual transaction price is the relevant consideration unless the case is explicitly modelled as `SPOUSEOUT`.

That leaves no structured way to represent cases where UK CGT uses deemed market value instead of actual consideration.

If future scope expands, it may be worth supporting:

- connected-person disposals/acquisitions
- gifts outside spouse/civil-partner no-gain/no-loss treatment
- negligible-value or other deemed-value scenarios, if those ever matter to target users

### 6. Consider modelling residence / capacity if broader support is wanted

If the project intends to support more than straightforward UK-resident personal portfolios, the model may eventually need metadata for:

- UK residence status at acquisition date
- capacity / beneficial ownership bucket
- perhaps share class / rights distinctions beyond simple asset ticker strings

Without that, some HMRC share-identification rules can only ever be approximated.

### 7. Consider whether `RESTRUCT` is enough for more complex reorganisations

The current `RESTRUCT old:new` input is useful for pure ratio-based restructures, but real reorganisations can involve additional elements such as:

- cash proceeds ("boot")
- multiple new securities
- class changes with apportionment issues
- events where part of the original holding remains and part converts

That does not mean the current implementation is wrong; it just means the supported corporate-action surface is narrower than some users may assume.

### 8. Add an explicit review fixture corpus for HMRC examples

There is already at least one HMRC example fixture, which is excellent.

Expanding that set would make regressions easier to spot, especially for:

- share matching ordering
- partial same-day matches
- post-sell rebuys with later same-day disposals
- accumulation distribution / equalisation cases
- annual exempt amount and loss-carry interactions across years
