@testable import CGTCalcCore
import XCTest

final class TaxReturnMathTests: XCTestCase {
  func testTaxReturnUsesPerDisposalRoundedValuesForTwoPenceGains() throws {
    let summary = try self.summary(
      for: """
      BUY 01/01/2020 A 2 1 0
      SELL 01/06/2020 A 1 1.99 0
      SELL 02/06/2020 A 1 1.99 0
      """,
      taxYearStart: 2020)

    XCTAssertEqual(summary.taxReturnMath.proceeds, 2)
    XCTAssertEqual(summary.taxReturnMath.allowableCosts, 2)
    XCTAssertEqual(summary.taxReturnMath.totalGains, 0)
    XCTAssertEqual(summary.taxReturnMath.totalLosses, 0)
  }

  func testTaxReturnUsesPerDisposalRoundedValuesForTwoPenceLosses() throws {
    let summary = try self.summary(
      for: """
      BUY 01/01/2020 A 2 1.99 0
      SELL 01/06/2020 A 1 1 0
      SELL 02/06/2020 A 1 1 0
      """,
      taxYearStart: 2020)

    XCTAssertEqual(summary.taxReturnMath.proceeds, 2)
    XCTAssertEqual(summary.taxReturnMath.allowableCosts, 2)
    XCTAssertEqual(summary.taxReturnMath.totalGains, 0)
    // Two 99p losses each floor to -£1 per disposal, so losses total £2.
    XCTAssertEqual(summary.taxReturnMath.totalLosses, 2)
  }

  func testTaxReturnUsesPerDisposalRoundedValuesForMixedPenceGainAndLoss() throws {
    let summary = try self.summary(
      for: """
      BUY 01/01/2020 A 2 1 0
      SELL 01/06/2020 A 1 1.99 0
      SELL 02/06/2020 A 1 0.01 0
      """,
      taxYearStart: 2020)

    XCTAssertEqual(summary.taxReturnMath.proceeds, 1)
    XCTAssertEqual(summary.taxReturnMath.allowableCosts, 2)
    XCTAssertEqual(summary.taxReturnMath.totalGains, 0)
    // The 99p loss floors to -£1 per disposal (the 99p gain floors to £0), so losses total £1.
    XCTAssertEqual(summary.taxReturnMath.totalLosses, 1)
  }

  func testTaxReturnUsesPerDisposalRoundedValuesForMixedSection104AndThirtyDayMatch() throws {
    let summary = try self.summary(
      for: """
      BUY 01/01/2020 A 10 1 0
      SELL 01/06/2020 A 10 1.99 0
      BUY 15/06/2020 A 5 1.5 0
      """,
      taxYearStart: 2020)

    XCTAssertEqual(summary.taxReturnMath.proceeds, 19)
    XCTAssertEqual(summary.taxReturnMath.allowableCosts, 12)
    XCTAssertEqual(summary.taxReturnMath.totalGains, 7)
    XCTAssertEqual(summary.taxReturnMath.totalLosses, 0)
  }

  func testTaxReturnUsesPerDisposalRoundedValuesForSameDayMergedDisposalsWithPence() throws {
    let summary = try self.summary(
      for: """
      BUY 01/01/2020 A 20 1 0
      SELL 01/06/2020 A 10 1.99 0
      SELL 01/06/2020 A 10 1.99 0
      """,
      taxYearStart: 2020)

    XCTAssertEqual(summary.disposals.count, 1)
    XCTAssertEqual(summary.taxReturnMath.proceeds, 39)
    XCTAssertEqual(summary.taxReturnMath.allowableCosts, 20)
    XCTAssertEqual(summary.taxReturnMath.totalGains, 19)
    XCTAssertEqual(summary.taxReturnMath.totalLosses, 0)
  }

  func testTaxReturnLinesUpWithRoundedDisposalWorkings() throws {
    let summary = try self.summary(
      for: """
      BUY 01/01/2020 A 2 1 0
      SELL 01/06/2020 A 1 2 0
      SELL 02/06/2020 A 1 0 0
      """,
      taxYearStart: 2020)

    let disposalRoundedGains = summary.disposals
      .filter(\.isGain)
      .reduce(Decimal(0)) { $0 + $1.gain }
    let disposalRoundedLosses = summary.disposals
      .filter(\.isLoss)
      .reduce(Decimal(0)) { $0 + abs($1.gain) }

    XCTAssertEqual(summary.taxReturnMath.totalGains, disposalRoundedGains)
    XCTAssertEqual(summary.taxReturnMath.totalLosses, disposalRoundedLosses)
  }

  func testTaxReturnProceedsAndAllowableCostsUseSamePerDisposalRoundingBasis() {
    let disposalA = TestSupport.disposal(
      asset: "A",
      date: "01/06/2020",
      gain: 0,
      rawGain: 0.01,
      rawProceeds: 1.99,
      rawAllowableCosts: 1.98)
    let disposalB = TestSupport.disposal(
      asset: "B",
      date: "02/06/2020",
      gain: 0,
      rawGain: 0.01,
      rawProceeds: 1.99,
      rawAllowableCosts: 1.98)
    let summary = TaxYearSummary(
      taxYear: TaxYear(startYear: 2020),
      disposals: [disposalA, disposalB],
      totalGain: 0,
      totalLoss: 0,
      netGain: 0,
      exemption: 12300,
      taxableGain: 0,
      lossCarryForward: 0)

    // Per-disposal rounding gives 1 + 1 = 2 for both, rather than floor(3.98)=3.
    XCTAssertEqual(summary.taxReturnMath.proceeds, 2)
    XCTAssertEqual(summary.taxReturnMath.allowableCosts, 2)
  }

  // MARK: - Aggregate rounding mode

  func testAggregateRoundingUsesHMRCDirections() {
    // HMRC SAM121370: income (proceeds, gains) rounds DOWN; costs/reliefs (allowable costs,
    // losses) round UP. Full precision is kept until these final aggregate totals are rounded.
    // proceeds 100.90 -> down 100; allowable costs 40.10 -> up 41; gain 60.80 -> down 60.
    let disposal = TestSupport.disposal(
      asset: "A",
      date: "01/06/2020",
      gain: 0,
      rawGain: 60.80,
      rawProceeds: 100.90,
      rawAllowableCosts: 40.10)
    let summary = TaxYearSummary(
      taxYear: TaxYear(startYear: 2020),
      disposals: [disposal],
      totalGain: 0, totalLoss: 0, netGain: 0,
      exemption: 12300, taxableGain: 0, lossCarryForward: 0)

    let aggregate = summary.taxReturnMath(rounding: .aggregate)
    XCTAssertEqual(aggregate.proceeds, 100)      // income rounded down
    XCTAssertEqual(aggregate.allowableCosts, 41) // costs rounded up
    XCTAssertEqual(aggregate.totalGains, 60)     // gains rounded down
    XCTAssertEqual(aggregate.totalLosses, 0)
  }

  func testAggregateRoundingReconcilesRealisticCase() {
    // A realistic single disposal with a dealing fee folded into allowable costs.
    // Raw: proceeds 9855.1245, allowable costs 7038.7462 (incl £5 fee), gain 2816.3783.
    // Directional: proceeds down 9855, costs up 7039, gain down 2816.
    // 9855 - 7039 = 2816 = gains - losses, so the four boxes reconcile.
    let disposal = TestSupport.disposal(
      asset: "A",
      date: "01/06/2025",
      gain: 0,
      rawGain: 2816.3783,
      rawProceeds: 9855.1245,
      rawAllowableCosts: 7038.7462)
    let summary = TaxYearSummary(
      taxYear: TaxYear(startYear: 2025),
      disposals: [disposal],
      totalGain: 0, totalLoss: 0, netGain: 0,
      exemption: 3000, taxableGain: 0, lossCarryForward: 0)

    let aggregate = summary.taxReturnMath(rounding: .aggregate)
    XCTAssertEqual(aggregate.proceeds, 9855)
    XCTAssertEqual(aggregate.allowableCosts, 7039)
    XCTAssertEqual(aggregate.totalGains, 2816)
    XCTAssertEqual(aggregate.totalLosses, 0)
    // The HMRC online-form identity holds.
    XCTAssertEqual(
      aggregate.proceeds - aggregate.allowableCosts,
      aggregate.totalGains - aggregate.totalLosses)
  }

  func testAggregateRoundingKeepsFullPrecisionUntilTotals() {
    // Two disposals: raw proceeds 1.99 each (sum 3.98), raw costs 1.98 each (sum 3.96).
    // Aggregate keeps precision then rounds the totals: proceeds down(3.98)=3, costs up(3.96)=4.
    // Per-disposal instead rounds each disposal first: proceeds 1+1=2, costs (up) 2+2=4.
    let disposalA = TestSupport.disposal(
      asset: "A", date: "01/06/2020", gain: 0,
      rawGain: 0.01, rawProceeds: 1.99, rawAllowableCosts: 1.98)
    let disposalB = TestSupport.disposal(
      asset: "B", date: "02/06/2020", gain: 0,
      rawGain: 0.01, rawProceeds: 1.99, rawAllowableCosts: 1.98)
    let summary = TaxYearSummary(
      taxYear: TaxYear(startYear: 2020),
      disposals: [disposalA, disposalB],
      totalGain: 0, totalLoss: 0, netGain: 0,
      exemption: 12300, taxableGain: 0, lossCarryForward: 0)

    let aggregate = summary.taxReturnMath(rounding: .aggregate)
    XCTAssertEqual(aggregate.proceeds, 3)        // down(3.98)
    XCTAssertEqual(aggregate.allowableCosts, 4)  // up(3.96)
    XCTAssertEqual(aggregate.totalGains, 0)      // down(0.02)
    XCTAssertEqual(aggregate.totalLosses, 0)     // up(0)
  }

  func testDefaultRoundingRemainsPerDisposal() {
    // The library default (no argument) must stay per-disposal so existing behaviour and
    // example fixtures are unchanged; only the CLI opts into aggregate.
    let disposal = TestSupport.disposal(
      asset: "A", date: "01/06/2020", gain: 0,
      rawGain: 0.99, rawProceeds: 1.99, rawAllowableCosts: 1.0)
    let summary = TaxYearSummary(
      taxYear: TaxYear(startYear: 2020),
      disposals: [disposal],
      totalGain: 0, totalLoss: 0, netGain: 0,
      exemption: 12300, taxableGain: 0, lossCarryForward: 0)

    // Default == per-disposal: gain floors to £0.
    XCTAssertEqual(summary.taxReturnMath.totalGains, summary.taxReturnMath(rounding: .perDisposal).totalGains)
    XCTAssertEqual(summary.taxReturnMath(rounding: .perDisposal).totalGains, 0)
    // Aggregate keeps precision then rounds the total down: down(0.99) = 0 here (single disposal).
    XCTAssertEqual(summary.taxReturnMath(rounding: .aggregate).totalGains, 0)
  }

  // MARK: - Summary/TaxReturn consistency

  func testReportedNetGainMatchesTaxReturnInformation() throws {
    // Three 3.90 gains: per-disposal floors each to £3 (sum £9); aggregate sums to 11.70 then
    // rounds the gain total down to £11. The SUMMARY Gain must equal the TAX RETURN INFORMATION
    // gains − losses under each mode.
    let summary = try self.summary(
      for: """
      BUY 01/01/2020 A 4 1 0
      SELL 01/06/2020 A 1 3.90 0
      SELL 02/06/2020 A 1 3.90 0
      SELL 03/06/2020 A 1 3.90 0
      """,
      taxYearStart: 2020)

    for mode in [RoundingMode.perDisposal, .aggregate] {
      let math = summary.taxReturnMath(rounding: mode)
      XCTAssertEqual(
        summary.reportedNetGain(rounding: mode),
        math.totalGains - math.totalLosses,
        "SUMMARY Gain must equal TAX RETURN gains − losses in \(mode) mode")
    }
    // The two modes actually differ here, so the test is meaningful.
    XCTAssertNotEqual(
      summary.reportedNetGain(rounding: .perDisposal),
      summary.reportedNetGain(rounding: .aggregate))
  }

  func testReportedNetGainPerDisposalEqualsHistoricNetGain() throws {
    // Per-disposal reportedNetGain must equal the engine's netGain, so the default SUMMARY
    // presentation is unchanged from before this consistency fix.
    let summary = try self.summary(
      for: """
      BUY 01/01/2020 A 2 1 0
      SELL 01/06/2020 A 1 2.90 0
      SELL 02/06/2020 A 1 0.10 0
      """,
      taxYearStart: 2020)
    XCTAssertEqual(summary.reportedNetGain(rounding: .perDisposal), summary.netGain)
  }

  func testReportedTaxableGainAppliesExemption() {
    let disposal = TestSupport.disposal(
      asset: "A", date: "01/06/2025", gain: 5000,
      rawGain: 5000.90, rawProceeds: 9000.90, rawAllowableCosts: 4000.0)
    let summary = TaxYearSummary(
      taxYear: TaxYear(startYear: 2025),
      disposals: [disposal],
      totalGain: 5000, totalLoss: 0, netGain: 5000,
      exemption: 3000, taxableGain: 2000, lossCarryForward: 0)
    // Aggregate: gain rounds down to 5000, minus 3000 exemption = 2000 taxable.
    XCTAssertEqual(summary.reportedTaxableGain(rounding: .aggregate), 2000)
  }

  private func summary(for input: String, taxYearStart: Int) throws -> TaxYearSummary {
    let data = try InputParser.parse(content: input)
    let result = try CGTEngine.calculate(inputData: data)
    return try XCTUnwrap(result.taxYearSummaries.first { $0.taxYear == TaxYear(startYear: taxYearStart) })
  }
}
