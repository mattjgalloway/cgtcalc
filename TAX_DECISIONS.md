# Tax Decisions

This document records UK CGT interpretation and implementation decisions that materially affect calculator behavior.

The aim is to make it clear:

- what the calculator intentionally does
- whether that behavior is an explicit HMRC rule, a scope choice, or an implementation inference
- where the behavior is pinned down in tests or fixtures

This is not legal advice. It is a project decision log.

## Scope

### Post-6 April 2008 only

- Decision: input dates before `06/04/2008` are rejected.
- Why: the calculator is intended to model the post-6 April 2008 share-identification regime only.
- Status: explicit scope boundary.
- Code:
  - `Sources/CGTCalcCore/Calculator/CGTEngine.swift`
  - `Sources/CGTCalcCore/Models/Calculation.swift`
- Tests:
  - `Tests/CGTCalcCoreTests/CalculatorTests.swift` `testPre2008InputDateThrowsUnsupportedScopeError`
  - `Tests/CGTCalcCoreTests/TestData/InvalidExamples/Inputs/UnsupportedPre2008Date.txt`

### Disposal tax years supported from 2013/2014 onwards

- Decision: annual exempt amount data is currently configured only for disposal tax years `2013/2014` onwards.
- Why: tax-year lookup data has only been populated from that point.
- Status: explicit scope boundary.
- User-facing wording:
  - `README.md`
- Code:
  - `Sources/CGTCalcCore/Models/TaxYear.swift`

### UK-resident assumption for 30-day matching

- Decision: 30-day matching assumes the disposer is UK resident at the time of the later acquisition.
- Why: the current input model has no way to represent residence status or changes in residence.
- Status: explicit scope assumption, not a full residence-aware implementation.
- User-facing wording:
  - `README.md`

### No HMRC later-acquisitions fallback stage

- Decision: if same-day, following-30-day, and Section 104 rules still do not fully identify a disposal, the calculator stops and raises an unsupported-case error.
- Why: the project currently does not implement HMRC's additional later-acquisitions fallback stage.
- Status: explicit unsupported case.
- Code:
  - `Sources/CGTCalcCore/Calculator/CGTEngine.swift`
  - `Sources/CGTCalcCore/Models/Calculation.swift`
- Tests:
  - `Tests/CGTCalcCoreTests/CalculatorTests.swift` `testUnsupportedLaterAcquisitionFallbackThrowsSpecificError`
  - `Tests/CGTCalcCoreTests/TestData/InvalidExamples/Inputs/UnsupportedLaterAcquisitionFallback.txt`

## Share Identification

### Core ordering for disposals

- Decision: share disposals are identified in this order:
  1. same-day acquisitions
  2. acquisitions in the following 30 days
  3. Section 104 holding
- Why: this follows the ordinary post-2008 UK share-identification rules within project scope.
- Status: intended core tax behavior.
- Code:
  - `Sources/CGTCalcCore/Calculator/CGTEngine.swift`
  - `Sources/CGTCalcCore/Calculator/BedAndBreakfastMatcher.swift`
  - `Sources/CGTCalcCore/Calculator/Section104Processor.swift`

### Same-day taxable sells are treated as one effective disposal

- Decision: same-asset same-day `SELL` rows are merged before matching and rounding.
- Why: same-day disposals of the same class are intended to be treated together.
- Status: intended tax behavior.
- Code:
  - `Sources/CGTCalcCore/Calculator/SameDayDisposalMerger.swift`
- Tests:
  - `Tests/CGTCalcCoreTests/SameDayDisposalMergerTests.swift`
  - `Tests/CGTCalcCoreTests/CalculatorTests.swift` `testSameDaySellsAreMergedBeforeRounding`

### Same-day mixed `SELL` and `SPOUSEOUT` share one identification pool

- Decision: same-day outbounds for the same asset are grouped for identification, even when they mix taxable sells and spouse/civil-partner no-gain/no-loss transfer-outs.
- Why: this avoids source-order dependence and treats same-day outbound identification consistently.
- Status: project interpretation based on same-day disposal treatment plus spouse transfers being disposals for identification purposes.
- Allocation rule:
  - shared matches are allocated back to individual same-day outbounds pro rata by quantity
- Code:
  - `Sources/CGTCalcCore/Calculator/CGTEngine.swift`
- Tests:
  - `Tests/CGTCalcCoreTests/CalculatorTests.swift` `testSameDaySellAndSpouseOutUseCombinedIdentificationRegardlessOfSourceOrder`
  - `Tests/CGTCalcCoreTests/TestData/Examples/Inputs/SameDaySellAndSpouseOutSellFirst.txt`
  - `Tests/CGTCalcCoreTests/TestData/Examples/Inputs/SameDaySellAndSpouseOutSpouseFirst.txt`

## Spouse / Civil Partner Transfers

### `SPOUSEOUT` uses ordinary disposal identification ordering

- Decision: `SPOUSEOUT` is costed using the same identification ordering as any other share disposal: same day, then following 30 days, then Section 104.
- Why: a qualifying spouse/civil-partner no-gain/no-loss transfer is still a disposal for identification purposes.
- Status: intended tax behavior.
- Code:
  - `Sources/CGTCalcCore/Calculator/CGTEngine.swift`
- Tests:
  - `Tests/CGTCalcCoreTests/CalculatorTests.swift` `testSpouseOutUsesSameDayAcquisitionPriorityBeforeSection104Pool`
  - `Tests/CGTCalcCoreTests/CalculatorTests.swift` `testSpouseOutUsesThirtyDayAcquisitionPriorityBeforeSection104Pool`

### `SPOUSEIN` is manual carry-over basis input

- Decision: `SPOUSEIN` takes a manually entered per-unit cost basis copied from the transferor's `SPOUSEOUT` run.
- Why: the calculator works one person at a time and does not join two taxpayers' histories automatically.
- Status: explicit product choice.
- User-facing wording:
  - `README.md`

### Future-buy reservation applies to spouse transfers too

- Decision: when a future buy day also has a same-day disposal, that day's buy quantity is reserved for that day's own same-day identification before any earlier `SPOUSEOUT` can use the remainder under the 30-day rule.
- Why: same-day priority on the future day should win before earlier 30-day matching consumes the buy.
- Status: intended tax behavior within the current matching model.
- Tests:
  - `Tests/CGTCalcCoreTests/CalculatorTests.swift` `testSpouseOutRespectsFutureBuyReservedForLaterSameDaySell`

## Fund Event Semantics

### `DIVIDEND` means accumulation distribution

- Decision: `DIVIDEND` rows represent accumulation distributions that increase allowable cost.
- Why: this project uses `DIVIDEND` specifically for the CGT cost-basis effect of accumulation funds, not for ordinary cash dividends.
- Status: explicit semantic choice.
- User-facing wording:
  - `README.md`

### `CAPRETURN` means capital return / equalisation

- Decision: `CAPRETURN` rows reduce allowable cost.
- Why: they model equalisation or other capital-return style adjustments relevant to pooled fund cost basis.
- Status: explicit semantic choice.
- User-facing wording:
  - `README.md`

### Asset events use effective / entitlement dates

- Decision: `DIVIDEND` and `CAPRETURN` should be entered on the effective or entitlement date for the holding, not just the later cash reporting date.
- Why: matching and pool adjustments depend on the holding state on the legally relevant date.
- Status: explicit input convention.
- User-facing wording:
  - `README.md`

### Same-day event rows are validated by aggregate amount

- Decision:
  - same-day `DIVIDEND` rows for one asset/date must sum to the holding quantity on that date
  - same-day `CAPRETURN` rows for one asset/date must sum to the Group II tranche still held at that date
- Why: multiple lines on one date are treated as one logical distribution event of that type.
- Status: intended validation behavior.
- Code:
  - `Sources/CGTCalcCore/Calculator/AssetEventValidator.swift`
- Tests:
  - `Tests/CGTCalcCoreTests/AssetEventValidatorTests.swift`

## Post-Buy Event Handling On Bed-And-Breakfast Matches

### Later fund events can adjust matched rebuy cost

- Decision: later `DIVIDEND` and `CAPRETURN` events can affect the allowable cost of a same-day or 30-day matched rebuy.
- Why: the rebuy remains the relevant holding for those later events unless and until later outbound use means otherwise.
- Status: intended tax behavior in the current model.

### Post-buy event offsets stop at the next outbound date

- Decision: later `DIVIDEND` / `CAPRETURN` offsets on a matched rebuy are only included through the next outbound date for that asset.
- Why: this avoids double-counting later fund events against an earlier bed-and-breakfast match once a later outbound changes which holding the event economically belongs to.
- Status: project interpretation to avoid double-counting.
- Code:
  - `Sources/CGTCalcCore/Calculator/BedAndBreakfastMatcher.swift`
- Tests:
  - `Tests/CGTCalcCoreTests/CalculatorTests.swift` `testPostBuyDividendIsNotDoubleCountedAcrossThirtyDayAndLaterSection104Disposals`
  - `Tests/CGTCalcCoreTests/TestData/Examples/Inputs/BBMultiplePostBuyEventsStopsAtNextOutbound.txt`

### Post-buy event offsets are scaled on the event-date quantity basis

- Decision: if a `SPLIT`, `UNSPLIT`, or `RESTRUCT` occurs between the rebuy and a later `DIVIDEND` / `CAPRETURN`, the matched rebuy quantity is first converted onto the later event-date basis before the event is apportioned.
- Why: the event amount is expressed on the event-date quantity basis, so apportionment must use the same basis.
- Status: intended tax behavior.
- Code:
  - `Sources/CGTCalcCore/Calculator/BedAndBreakfastMatcher.swift`
- Tests:
  - `Tests/CGTCalcCoreTests/BedAndBreakfastMatcherTests.swift` `testEventAdjustmentScalesMatchedQuantityAcrossSplitBeforeDividend`
  - `Tests/CGTCalcCoreTests/BedAndBreakfastMatcherTests.swift` `testEventAdjustmentScalesMatchedQuantityAcrossUnsplitBeforeDividend`
  - `Tests/CGTCalcCoreTests/TestData/Examples/Inputs/BBDividendAfterSplitScalesMatchedQuantity.txt`
  - `Tests/CGTCalcCoreTests/TestData/Examples/Inputs/BBDividendAfterUnsplitScalesMatchedQuantity.txt`

## Rounding And Reporting

### Gain/loss rounding happens per disposal before annual aggregation

- Decision: each disposal gain or loss is rounded down to whole pounds before tax-year totals are aggregated.
- Why: the project chooses to mirror HMRC-style per-disposal working and examples, where each disposal computation is treated as its own rounded figure before summarizing.
- Status: explicit project policy.
- Code:
  - `Sources/CGTCalcCore/Models/TaxMethods.swift`
  - `Sources/CGTCalcCore/Calculator/CGTEngine.swift`
  - `Sources/CGTCalcCore/Calculator/TaxYearSummarizer.swift`
- Note:
  - this is an implementation policy choice and should be preserved unless the project deliberately decides to move to raw-amount annual aggregation instead

### Summary proceeds are reported as whole pounds

- Decision: the summary section reports proceeds rounded down to whole pounds.
- Why: this is a reporting simplification used consistently in the current formatter.
- Code:
  - `Sources/CGTCalcCore/Formatter/TaxReturnMath.swift`
  - `Sources/CGTCalcCore/Formatter/TextReportFormatter.swift`

## Restructures

### `SPLIT`, `UNSPLIT`, and `RESTRUCT` are pure quantity-basis changes

- Decision: these events rescale quantities while preserving pooled allowable cost.
- Why: the current model treats them as ratio-based quantity restructures without cash proceeds or multiple replacement assets.
- Status: intended supported corporate-action scope.
- Code:
  - `Sources/CGTCalcCore/Calculator/Section104Processor.swift`
  - `Sources/CGTCalcCore/Calculator/BedAndBreakfastMatcher.swift`
- User-facing wording:
  - `README.md`

### More complex reorganisations are out of scope

- Decision: the calculator does not attempt to model broader reorganisation cases such as cash boot, multiple new securities, or connected-party deemed-market-value substitutions unless explicitly represented by supported rows.
- Why: current input rows and pool logic do not encode those scenarios.
- Status: scope boundary by omission.

## How To Use This File

When behavior is disputed, update this file with:

1. the decision
2. the reason for it
3. whether it is an explicit HMRC rule, an inference, or a scope/product choice
4. the tests or fixtures that pin it down

If the implementation changes in a way that alters tax outcomes, this file should be updated in the same change.
