@testable import CGTCalcCore
import XCTest

final class ReportDocumentTests: XCTestCase {
  func testProjectsSharedDisposalEconomicsOnce() throws {
    let sell = TestSupport.sell("15/11/2024", "FOO", 10, 20, 1)
    let buy = try TestSupport.buy("15/11/2024", "FOO", 20, XCTUnwrap(Decimal.parse("12.34567")), 2)
    let acquisitionMatch = try BedAndBreakfastMatch(
      buyTransaction: buy,
      quantity: 4,
      buyDateQuantity: 8,
      eventAdjustment: XCTUnwrap(Decimal.parse("-1.25")),
      cost: 50)
    let sectionMatch = Section104Match(
      transactionId: UUID(),
      quantity: 6,
      cost: 60,
      date: TestSupport.date("01/01/2020"),
      poolQuantity: 30,
      poolCost: 300)
    let disposal = Disposal(
      sellTransaction: sell,
      taxYear: TaxYear(startYear: 2024),
      gain: 89,
      section104Matches: [sectionMatch],
      bedAndBreakfastMatches: [acquisitionMatch])

    let entry = DisposalReportEntry(disposal: disposal)
    let projectedMatch = try XCTUnwrap(entry.acquisitionMatches.first)
    let projectedSection104 = try XCTUnwrap(entry.section104)

    XCTAssertEqual(projectedMatch.kind, .sameDay)
    XCTAssertEqual(projectedMatch.quantity, 8)
    XCTAssertEqual(projectedMatch.purchasePrice, Decimal.parse("12.34567"))
    XCTAssertEqual(projectedMatch.purchaseExpenses, Decimal.parse("0.8"))
    XCTAssertEqual(projectedMatch.eventAdjustment, Decimal.parse("-1.25"))
    XCTAssertEqual(projectedSection104.poolQuantity, 30)
    XCTAssertEqual(projectedSection104.poolCost, 300)
    XCTAssertEqual(projectedSection104.averageCost, 10)
    XCTAssertEqual(projectedSection104.matchedQuantity, 6)
    XCTAssertEqual(projectedSection104.matchedCost, 60)
  }

  func testProjectsTaxYearCountsAndTotals() {
    let summary = TaxYearSummary(
      taxYear: TaxYear(startYear: 2024),
      disposals: [
        TestSupport.disposal(date: "01/06/2024", gain: 10),
        TestSupport.disposal(date: "02/06/2024", gain: 0),
        TestSupport.disposal(date: "03/06/2024", gain: -4)
      ],
      totalGain: 10,
      totalLoss: 4,
      netGain: 6,
      exemption: 3000,
      taxableGain: 0,
      lossCarryForward: 0)

    let section = TaxYearReportSection(summary: summary)

    XCTAssertEqual(section.gainsCount, 2)
    XCTAssertEqual(section.lossesCount, 1)
    XCTAssertEqual(section.totalGains, 10)
    XCTAssertEqual(section.totalLosses, 4)
  }
}
