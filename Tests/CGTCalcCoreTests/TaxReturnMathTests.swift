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
    XCTAssertEqual(summary.taxReturnMath.totalLosses, 0)
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
    XCTAssertEqual(summary.taxReturnMath.totalLosses, 0)
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

  private func summary(for input: String, taxYearStart: Int) throws -> TaxYearSummary {
    let data = try InputParser.parse(content: input)
    let result = try CGTEngine.calculate(inputData: data)
    return try XCTUnwrap(result.taxYearSummaries.first { $0.taxYear == TaxYear(startYear: taxYearStart) })
  }
}
