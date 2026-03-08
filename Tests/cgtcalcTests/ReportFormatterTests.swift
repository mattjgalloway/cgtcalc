@testable import cgtcalc
import CGTCalcCore
import Foundation
import XCTest

final class ReportFormatterTests: XCTestCase {
  func testTextReportFormatterRendersText() throws {
    let result = self.makeResult()
    let rendered = try TextReportFormatter().render(result)

    switch rendered {
    case .text(let output):
      XCTAssertTrue(output.contains("# SUMMARY"))
      XCTAssertTrue(output.contains("TAX RETURN INFORMATION"))
    case .binary:
      XCTFail("Expected text output")
    }
  }

  #if os(macOS)
    func testPDFReportFormatterRendersPDFDataWithExpectedSections() throws {
      let result = self.makeResult(transactionCount: 160)
      let rendered = try PDFReportFormatter().render(result)

      switch rendered {
      case .binary(let data):
        XCTAssertTrue(data.starts(with: Data("%PDF".utf8)))
        XCTAssertGreaterThan(data.count, 1000)
      case .text:
        XCTFail("Expected PDF binary output")
      }
    }

    func testPDFTaxReturnEntryMatchesExpectedHMRCValues() throws {
      let result = self.makeResult()
      let summary = try XCTUnwrap(result.taxYearSummaries.first)
      let entry = PDFReportFormatter().taxReturnEntry(for: summary)

      XCTAssertEqual(
        entry.rows.map(\.label),
        ["Disposals", "Proceeds", "Allowable costs", "Total gains", "Total losses"])
      XCTAssertEqual(entry.rows.map(\.value), ["1", "1200", "805", "395", "0"])
      XCTAssertNil(entry.specialLine)
    }

    func testPDFDetailedCalculationLineIncludesCostComponents() throws {
      let result = self.makeResult()
      let disposal = try XCTUnwrap(result.taxYearSummaries.first?.disposals.first)
      let line = PDFReportFormatter().detailedCalculationLine(for: disposal)
      XCTAssertEqual(line, "Calculation: (100 * 12 - 3) - ( (100 * 8) ) = 395")
    }
  #endif

  private func makeResult(transactionCount: Int = 2) -> CalculationResult {
    let taxYear = TaxYear(startYear: 2023)
    let buy = Transaction(type: .buy, date: self.date("01/05/2023"), asset: "FOO", quantity: 200, price: 8, expenses: 2)
    let sell = Transaction(
      type: .sell,
      date: self.date("01/06/2023"),
      asset: "FOO",
      quantity: 100,
      price: 12,
      expenses: 3)
    let disposal = Disposal(
      sellTransaction: sell,
      taxYear: taxYear,
      gain: 395,
      section104Matches: [
        Section104Match(
          transactionId: buy.id,
          quantity: 100,
          cost: 800,
          date: buy.date,
          poolQuantity: 200,
          poolCost: 1600)
      ],
      bedAndBreakfastMatches: [])
    let summary = TaxYearSummary(
      taxYear: taxYear,
      disposals: [disposal],
      totalGain: 395,
      totalLoss: 0,
      netGain: 395,
      exemption: 6000,
      taxableGain: 0,
      lossCarryForward: 0)

    let txs: [Transaction] = if transactionCount <= 2 {
      [buy, sell]
    } else {
      (0 ..< transactionCount).map { index in
        let type: TransactionType = index.isMultiple(of: 2) ? .buy : .sell
        let day = 1 + (index % 28)
        return Transaction(
          type: type,
          date: self.date(String(format: "%02d/07/2023", day)),
          asset: "FOO",
          quantity: 1 + Decimal(index % 7),
          price: 10 + Decimal(index % 5),
          expenses: 1)
      }
    }

    return CalculationResult(
      taxYearSummaries: [summary],
      transactions: txs,
      assetEvents: [],
      lossCarryForward: 0,
      holdings: [
        "FOO": Section104Holding(quantity: 100, costBasis: 800, pool: [])
      ])
  }

  private func date(_ value: String) -> Date {
    try! DateParser.parse(value)
  }
}
