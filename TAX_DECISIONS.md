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

### Built-in disposal tax years are supported from 2013/2014 onwards

- Decision: the built-in HMRC provider contains annual exempt amount data for disposal tax years `2013/2014` onwards. Direct library callers may inject a `TaxRateProvider` for other years; missing provider data remains an explicit error.
- Why: tax-year lookup data has only been populated from that point.
- Status: explicit scope boundary.
- User-facing wording:
  - `README.md`
- Code:
  - `Sources/CGTCalcCore/Models/TaxYear.swift`
  - `Sources/CGTCalcCore/Calculator/TaxYearSummarizer.swift`

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

### Same-date ordering architecture

- Decision: input row order must not change a tax result unless the input model explicitly defines the rows as sequential and documents that sequence as tax-significant.
- Why: input rows contain calendar dates rather than reliable legal intraday timestamps. Source order, dictionary order, and generated UUID order are not tax facts.
- Status: project-wide architecture for all same-date processing.

General rules:

1. Rows on different dates are processed chronologically.
2. Same-date rows are grouped, aggregated, or processed in a canonical tax order where the supported tax treatment determines one.
3. If date-only input cannot establish a legally necessary sequence and no safe canonical treatment exists, every permutation must fail with the same explicit unsupported-case error rather than produce different answers.
4. Stable semantic keys may be used for deterministic arithmetic residual placement, but residual assignment must not create a meaningful tax difference.
5. Public API inputs without `sourceOrder` must produce the same tax result as equivalent parsed input; random UUIDs must not decide tax outcomes.

Supported same-date behavior:

- same-class acquisitions are treated together for same-day identification and their aggregate cost is conserved
- same-asset taxable sells are one effective disposal
- mixed `SELL` and `SPOUSEOUT` rows share one identification pool and receive pro-rata allocations
- `SPOUSEIN` participates as a same-day acquisition
- same-asset/date/type `DIVIDEND` rows form one logical event
- same-asset/date/type `CAPRETURN` rows form one logical event
- when `DIVIDEND` and `CAPRETURN` are components on the same asset/date, the Group II share of the accumulation `DIVIDEND` uplift is reflected before the `CAPRETURN` cost-floor validation, regardless of input row order
- one `SPLIT`, `UNSPLIT`, or `RESTRUCT` may share a date with `SELL` and/or `SPOUSEOUT`; the restructure is effective before the outbounds and outbound quantities must use the post-restructure basis

Unsupported same-date behavior:

- `DIVIDEND` or `CAPRETURN` with any transaction or restructure for the same asset, because date-only input cannot determine event entitlement
- `SPLIT`, `UNSPLIT`, or `RESTRUCT` with `BUY` or `SPOUSEIN`, because date-only input cannot determine the acquisition's quantity basis
- more than one restructure for the same asset/date, because the input does not define a reliable sequence or intermediate basis

These combinations raise `unsupportedSameDateCombination` for every input permutation. Different assets remain independent.

Regression standard:

- For each supported same-date combination, permutation tests must assert identical raw disposals, rounded gains/losses, match allocations, spouse transfer cost, event allocation, and final holdings.
- For an unsupported ambiguous combination, permutation tests must assert the same explicit error.
- Adding a new row type or same-date interaction requires an ordering decision and permutation coverage.
- Code:
  - `Sources/CGTCalcCore/Calculator/CalculationTimeline.swift`
- Tests:
  - `Tests/CGTCalcCoreTests/CalculationTimelineGroupingTests.swift`
  - `Tests/CGTCalcCoreTests/CalculationTimelineValidationTests.swift`
  - `Tests/CGTCalcCoreTests/CalculatorTests.swift` `testSameDateTransactionPermutationsProduceIdenticalEconomics`
  - `Tests/CGTCalcCoreTests/CalculatorTests.swift` `testSameDateDistributionOrderIsIndependentOfPublicAPIArrayOrderAndUUIDs`
  - `Tests/CGTCalcCoreTests/CalculatorTests.swift` `testSameDateRestructureAndOutboundUsePostRestructureBasisRegardlessOfInputOrder`
  - `Tests/CGTCalcCoreTests/TestData/Examples/Inputs/SameDateDividendAndCapitalReturn.txt`
  - `Tests/CGTCalcCoreTests/TestData/InvalidExamples/Inputs/UnsupportedSameDateEntitlement.txt`

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

### `SPOUSEIN` uses a lossless manual carry-over basis

- Decision: the canonical spouse handoff is the exact `TOTALCOST` input row emitted by the transferor's `SPOUSEOUT` report. The displayed per-unit average is informational only; legacy per-unit `SPOUSEIN` input remains supported.
- Why: the calculator works one person at a time and does not join two taxpayers' histories automatically.
- Why: copying a display-rounded per-unit average can change the recipient's allowable cost, especially for large or fractional quantities.
- Status: explicit product choice.
- User-facing wording:
  - `README.md`
- Tests:
  - `Tests/CGTCalcCoreTests/ParserTests.swift` `testParseSpouseInWithExactTotalCost`
  - `Tests/CGTCalcCoreTests/CalculatorTests.swift` `testExactTotalCostSpouseHandoffPreservesRecipientBasis`
  - `Tests/CGTCalcCoreTests/TestData/Examples/Inputs/SpouseInExactTotalCost.txt`

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
- Supported scope: fund equalisation cost reductions only. A `CAPRETURN` cannot reduce the cost attributable to its eligible Group II units below zero; excess values are rejected because general capital distributions require part-disposal rules outside the current model.
- Group II attributable cost includes the acquisition cost and expenses of the eligible Group II units, adjusted by same-period distributions. It is tracked separately from the legal Section 104 pool average.
- Physical outbounds deplete Group II provenance even where ordinary share identification assigns their legal allowable cost elsewhere. `SPLIT`, `UNSPLIT`, and `RESTRUCT` rescale the eligible quantity without changing its cost, and a distribution starts a new Group II period for later acquisitions.
- A monetary tolerance of £0.0001 permits harmless decimal dust at the zero-cost boundary.
- Why: they model equalisation or other capital-return style adjustments relevant to pooled fund cost basis.
- Why: the whole Section 104 average can contain older Group I cost and therefore is not the cost floor for a return attributable specifically to Group II units.
- Status: explicit semantic choice.
- User-facing wording:
  - `README.md`
- Code:
  - `Sources/CGTCalcCore/Calculator/Section104Processor.swift`
- Tests:
  - `Tests/CGTCalcCoreTests/CalculatorTests.swift` `testCapitalReturnUsesHighCostGroupIITrancheInsteadOfPoolAverage`
  - `Tests/CGTCalcCoreTests/TestData/Examples/Inputs/GroupIICapitalReturnUsesAttributableCost.txt`
  - `Tests/CGTCalcCoreTests/TestData/InvalidExamples/Inputs/GroupIICapitalReturnExceedsAttributableCost.txt`

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
  - rows are grouped separately by asset, UTC calendar date, and event type; both amount and value are summed before cost-basis apportionment
  - both validations allow a small broker/fund rounding tolerance of `max(0.0001, expected units * 0.00001)`
  - an amount accepted within that tolerance is normalized to the eligible quantity established by validation; event value is apportioned proportionately using eligible event-date quantities, independent of disposal processing order
  - proportional event values use nearest rounding at 10 decimal places before entering matched or Section 104 cost-basis calculations; this removes non-economic repeating-decimal residue without applying tax-report whole-pound rounding early
- Why: multiple lines on one date are treated as one logical distribution event of that type, while the tolerance accepts harmless broker/platform fractional-unit dust without accepting meaningful mismatches.
- Status: intended validation behavior.
- Code:
  - `Sources/CGTCalcCore/Calculator/AssetEventValidator.swift`
- Tests:
  - `Tests/CGTCalcCoreTests/AssetEventValidatorTests.swift`

## Post-Buy Event Handling On Bed-And-Breakfast Matches

### Later fund events can adjust matched rebuy cost

- Decision: later `DIVIDEND` and `CAPRETURN` events can affect the allowable cost of a same-day or 30-day matched rebuy.
- Any event value allocated to an identified rebuy is deducted before the residual event value is applied to the Section 104 holding. The event value therefore affects allowable cost exactly once across matches and the pool.
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

### Precision and rounding architecture

- Decision: economic values are preserved through calculation and taxpayer-to-taxpayer handoff; rounding is applied only at a named boundary for a named purpose.
- Status: project-wide architecture. New calculation code and reviews should use these rules rather than introducing local rounding conventions.

The stages are deliberately separate:

1. **Input precision**
   - Valid input prices, quantities, expenses, distribution values, and transferred costs are parsed as `Decimal` and retained as entered.
   - Input values are not rounded merely to match report display precision.
2. **Core calculation precision**
   - Acquisition cost, proceeds, expenses, Section 104 cost, share matching, and raw gains retain full practical `Decimal` precision.
   - Intermediate values are not rounded unless division has created non-economic representation residue covered by an explicit normalization policy.
3. **Apportionment precision**
   - Division-generated event and shared-acquisition allocations use nearest rounding at 10 decimal places.
   - Allocated destinations and the final residual must reconcile exactly to the original event or acquisition value.
   - Any arithmetic residual is assigned once and deterministically; processing or input order must not create a meaningful difference.
   - Pro-rata allocation from a combined same-day outbound group uses cumulative 10-decimal allocation in canonical economic order, with exact reconciliation to the combined matches.
   - A partial Section 104 disposal uses the full `Decimal` proportional pooled cost. Full pool consumption uses the exact remaining pooled cost.
   - Same-day merged sells retain exact aggregate proceeds separately from the weighted per-unit price used for display.
4. **Tax reporting precision**
   - Whole-pound tax rounding is applied only at the agreed disposal/reporting boundary described below.
   - Tax reporting rounding must not be reused as an intermediate calculation or allocation rule.
5. **Display precision**
   - Text and PDF rounding exists only to render values for a person.
   - Display-rounded values must not feed later calculations or be presented as authoritative handoff data.
6. **Lossless handoffs**
   - When output from one taxpayer's calculation is input to another taxpayer's calculation, the canonical transferred value must preserve the exact calculation basis.
   - In particular, a spouse/civil-partner transfer must hand over exact total transferred cost; a rounded explanatory per-unit average is not authoritative.
7. **Tolerance policy**
   - Approximate comparisons use named quantity or monetary tolerances with documented units and purpose.
   - Tolerance accepts harmless source or arithmetic dust; it must not silently move a meaningful value across a tax boundary.
   - `max(0, ...)` is not a substitute for validation when a negative value would indicate an unsupported or inconsistent tax state.
   - Asset-event quantity validation uses `max(0.0001, expected units * 0.00001)`; the CAPRETURN zero-cost boundary uses a £0.0001 monetary tolerance.
   - Internal matching uses a fixed `0.00000001` unit tolerance only for arithmetic residue from proportional allocation or restructure ratios. Near-equal full-pool consumption receives the exact remaining pool cost and normalizes the residual holding to zero; larger shortfalls remain errors.

Implementation guidance:

- Prefer purpose-specific helpers whose names expose the policy, for example `normalizedAllocation`, `roundedDisposalFigure`, `quantitiesMatch`, and `amountsMatch`.
- Keep report formatting helpers separate from calculation helpers.
- Avoid adding direct calls to generic fixed-scale rounding in calculator code unless the applicable policy is clear at the call site.
- Tests should cover exact boundaries, values immediately above and below boundaries, conservation, and order independence.

The retrospective precision audit confirmed the reporting boundary and corrected four conservation paths: shared bed-and-breakfast acquisition cost including expenses, exact proceeds from merged same-day sells, exact cost depletion when a Section 104 pool is fully consumed, and exact reconciliation when shared matches are allocated across mixed same-day outbounds. Text and PDF reports use the same calculation model, and spouse handoff uses exact total cost rather than display-rounded values.

Tests:

- `Tests/CGTCalcCoreTests/CalculatorTests.swift` `testSharedRebuyCostIncludingExpensesIsConservedAcrossDisposals`
- `Tests/CGTCalcCoreTests/SameDayDisposalMergerTests.swift` `testMergedWeightedPriceReconstructsExactOriginalProceeds`
- `Tests/CGTCalcCoreTests/Section104ProcessorTests.swift` `testSellingEntireRepeatingAveragePoolConsumesExactCost`
- `Tests/CGTCalcCoreTests/CalculatorTests.swift` `testSameDateTransactionPermutationsProduceIdenticalEconomics`

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

### Summary proceeds are the sum of disposal-level rounded proceeds

- Decision: the summary section reports proceeds as the sum of each disposal's rounded proceeds.
- Why: this keeps the summary on the same per-disposal-rounded basis as the disposal workings and tax-return reporting.
- Code:
  - `Sources/CGTCalcCore/Formatter/TaxReturnMath.swift`
  - `Sources/CGTCalcCore/Formatter/TextReportFormatter.swift`

### Tax-return figures use per-disposal rounded values

- Decision:
  - `proceeds` are the sum of rounded per-disposal proceeds
  - `allowable costs` are the sum of rounded per-disposal allowable costs
  - `total gains` are the sum of rounded positive per-disposal gains
  - `total losses` are the sum of rounded positive per-disposal losses
- Why:
  - the project keeps the disposal workings, top summary, and tax-return section on one coherent rounding basis
  - this avoids introducing a separate raw-total box-rounding regime that would create broader visible output changes and make the report harder to follow
- Status: explicit project reporting policy.
- Code:
  - `Sources/CGTCalcCore/Formatter/TaxReturnMath.swift`
  - `Sources/CGTCalcCore/Models/Calculation.swift`
  - `Sources/CGTCalcCore/Calculator/CGTEngine.swift`
- Tests:
  - `Tests/CGTCalcCoreTests/TaxReturnMathTests.swift`
  - `Tests/CGTCalcCoreTests/PDFReportWriterTests.swift`
  - `Tests/CGTCalcCoreTests/TestData/Examples/Outputs/TaxReturnTotalsPenceRounding.txt`

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
