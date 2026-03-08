@testable import CGTCalcCore
import Foundation
import XCTest
#if os(macOS)
  import PDFKit

  final class PDFReportWriterTests: XCTestCase {
    /// Set this true to re-record all PDF text snapshots, then set back to false.
    private let recordPDFFixtures = false

    func testPDFReportFormatterRendersPDFDataWithExpectedSections() throws {
      let result = ReportFormatterFixtureFactory.makeResult(transactionCount: 160)
      let rendered = try self.makePDFFormatter().render(result)

      switch rendered {
      case .binary(let data):
        XCTAssertTrue(data.starts(with: Data("%PDF".utf8)))
        XCTAssertGreaterThan(data.count, 1000)
        let document = try XCTUnwrap(PDFDocument(data: data))
        XCTAssertGreaterThan(document.pageCount, 1)
      case .text:
        XCTFail("Expected PDF binary output")
      }
    }

    func testPDFSnapshotSinglePageMatchesFixture() throws {
      let result = ReportFormatterFixtureFactory.makeResult()
      let snapshot = try self.extractPDFSnapshotText(from: self.renderPDF(result))
      try self.assertSnapshot(named: "single_page", actual: snapshot)
    }

    func testPDFSnapshotMultiPageMatchesFixture() throws {
      let result = ReportFormatterFixtureFactory.makeResult(transactionCount: 220)
      let snapshot = try self.extractPDFSnapshotText(from: self.renderPDF(result))
      try self.assertSnapshot(named: "multi_page", actual: snapshot)
      XCTAssertTrue(snapshot.contains("Transactions (cont.)"))
    }

    func testPDFTaxReturnEntryMatchesExpectedHMRCValues() throws {
      let result = ReportFormatterFixtureFactory.makeResult()
      let summary = try XCTUnwrap(result.taxYearSummaries.first)
      let entry = PDFReportFormatter().taxReturnEntry(for: summary)

      XCTAssertEqual(
        entry.rows.map(\.label),
        ["Disposals", "Proceeds", "Allowable costs", "Total gains", "Total losses"])
      XCTAssertEqual(entry.rows.map(\.value), ["1", "1200", "805", "395", "0"])
      XCTAssertNil(entry.specialLine)
    }

    func testPDFDetailedCalculationLineIncludesCostComponents() throws {
      let result = ReportFormatterFixtureFactory.makeResult()
      let disposal = try XCTUnwrap(result.taxYearSummaries.first?.disposals.first)
      let line = PDFReportFormatter().detailedCalculationLine(for: disposal)
      XCTAssertEqual(line, "Calculation: (100 * 12 - 3) - ( (100 * 8) ) = 395")
    }

    func testPDFDetailedCalculationLineIncludesBedAndBreakfastComponents() {
      let sell = Transaction(
        type: .sell,
        date: TestSupport.date("15/11/2024"),
        asset: "FOO",
        quantity: 10,
        price: 20,
        expenses: 1)
      let buy = Transaction(
        type: .buy,
        date: TestSupport.date("15/11/2024"),
        asset: "FOO",
        quantity: 20,
        price: 12.34567,
        expenses: 2)
      let match = BedAndBreakfastMatch(
        buyTransaction: buy,
        quantity: 4,
        buyDateQuantity: 8,
        eventAdjustment: -1.25,
        cost: 50)
      let disposal = Disposal(
        sellTransaction: sell,
        taxYear: TaxYear(startYear: 2024),
        gain: 100,
        section104Matches: [],
        bedAndBreakfastMatches: [match])

      let line = PDFReportFormatter().detailedCalculationLine(for: disposal)
      XCTAssertEqual(line, "Calculation: (10 * 20 - 1) - ( (8 * 12.34567 + 0.8 + -1.25) ) = 100")
    }

    func testPDFSnapshotForEmptyResultShowsNoneSections() throws {
      let result = CalculationResult(
        taxYearSummaries: [],
        transactions: [],
        assetEvents: [],
        lossCarryForward: 0,
        holdings: [:])

      let snapshot = try self.extractPDFSnapshotText(from: self.renderPDF(result))

      XCTAssertTrue(snapshot.contains("No disposals."))
      XCTAssertTrue(snapshot.contains("Tax Return Information"))
      XCTAssertTrue(snapshot.contains("None."))
      XCTAssertTrue(snapshot.contains("Holdings"))
      XCTAssertTrue(snapshot.contains("Transactions"))
      XCTAssertTrue(snapshot.contains("Asset Events"))
      XCTAssertTrue(snapshot.contains("NONE"))
    }

    func testPDFSnapshotWithSpecialRateChangeAndAssetEventsCoversBranches() throws {
      let before = Transaction(
        type: .sell,
        date: TestSupport.date("28/10/2024"),
        asset: "EVENT-ASSET",
        quantity: 10,
        price: 20,
        expenses: 0)
      let after = Transaction(
        type: .sell,
        date: TestSupport.date("30/10/2024"),
        asset: "EVENT-ASSET",
        quantity: 5,
        price: 30,
        expenses: 0)
      let disposalBefore = Disposal(
        sellTransaction: before,
        taxYear: TaxYear(startYear: 2024),
        gain: 40,
        section104Matches: [],
        bedAndBreakfastMatches: [])
      let disposalAfter = Disposal(
        sellTransaction: after,
        taxYear: TaxYear(startYear: 2024),
        gain: 15,
        section104Matches: [],
        bedAndBreakfastMatches: [])
      let summary = TaxYearSummary(
        taxYear: TaxYear(startYear: 2024),
        disposals: [disposalBefore, disposalAfter],
        totalGain: 55,
        totalLoss: 0,
        netGain: 55,
        exemption: 3000,
        taxableGain: 0,
        lossCarryForward: 0)

      let asset = "EVENT-ASSET"
      let events: [AssetEvent] = [
        AssetEvent(type: .split, date: TestSupport.date("01/01/2025"), asset: asset, amount: 2, value: 0),
        AssetEvent(type: .unsplit, date: TestSupport.date("02/01/2025"), asset: asset, amount: 2, value: 0),
        AssetEvent(type: .capitalReturn, date: TestSupport.date("03/01/2025"), asset: asset, amount: 10, value: 5),
        AssetEvent(type: .dividend, date: TestSupport.date("04/01/2025"), asset: asset, amount: 10, value: 6)
      ]

      let result = CalculationResult(
        taxYearSummaries: [summary],
        transactions: [],
        assetEvents: events,
        lossCarryForward: 0,
        holdings: [:])

      let snapshot = try self.extractPDFSnapshotText(from: self.renderPDF(result))
      XCTAssertTrue(snapshot.contains("Rate-change split: gains to 29th October = 40; gains after 29th October = 15."))
      XCTAssertTrue(snapshot.contains("SPLIT by 2"))
      XCTAssertTrue(snapshot.contains("UNSPLIT by 2"))
      XCTAssertTrue(snapshot.contains("CAPITAL RETURN on 10 for £5"))
      XCTAssertTrue(snapshot.contains("DIVIDEND on 10 for £6"))
    }

    func testPDFSnapshotWithLargeHoldingsRepeatsTableHeaderAndTruncatesText() throws {
      let veryLongAsset = String(repeating: "LONG-ASSET-NAME-", count: 15)
      var holdings: [String: Section104Holding] = [:]
      for i in 0 ..< 90 {
        holdings["\(veryLongAsset)\(i)"] = Section104Holding(quantity: 10, costBasis: 100, pool: [])
      }

      let result = CalculationResult(
        taxYearSummaries: [],
        transactions: [],
        assetEvents: [],
        lossCarryForward: 0,
        holdings: holdings)
      let pdfData = try self.renderPDF(result)
      let snapshot = try self.extractPDFSnapshotText(from: pdfData)
      let document = try XCTUnwrap(PDFDocument(data: pdfData))

      XCTAssertGreaterThan(document.pageCount, 1)
      XCTAssertFalse(snapshot.contains("\(veryLongAsset)0"))
    }

    func testPDFSnapshotWithVeryLargeDisposalUsesUnboxedFallback() throws {
      let hugeAsset = String(repeating: "EXTREMELY-LONG-ASSET-NAME-", count: 50)
      let sell = Transaction(
        type: .sell,
        date: TestSupport.date("01/06/2023"),
        asset: hugeAsset,
        quantity: 100,
        price: 12,
        expenses: 3)

      let bedAndBreakfastMatches: [BedAndBreakfastMatch] = (0 ..< 180).map { idx in
        let buy = Transaction(
          type: .buy,
          date: TestSupport.date("01/06/2023"),
          asset: hugeAsset,
          quantity: 200,
          price: 10 + Decimal(idx % 5),
          expenses: 2)
        return BedAndBreakfastMatch(
          buyTransaction: buy,
          quantity: 1,
          buyDateQuantity: 1,
          eventAdjustment: idx.isMultiple(of: 2) ? 0 : -0.01,
          cost: 10)
      }

      let disposal = Disposal(
        sellTransaction: sell,
        taxYear: TaxYear(startYear: 2023),
        gain: 1,
        section104Matches: [],
        bedAndBreakfastMatches: bedAndBreakfastMatches)
      let summary = TaxYearSummary(
        taxYear: TaxYear(startYear: 2023),
        disposals: [disposal],
        totalGain: 1,
        totalLoss: 0,
        netGain: 1,
        exemption: 6000,
        taxableGain: 0,
        lossCarryForward: 0)
      let result = CalculationResult(
        taxYearSummaries: [summary],
        transactions: [],
        assetEvents: [],
        lossCarryForward: 0,
        holdings: [:])

      let snapshot = try self.extractPDFSnapshotText(from: self.renderPDF(result))
      XCTAssertTrue(snapshot.contains("Same day:"))
    }

    private func makePDFFormatter() throws -> PDFReportFormatter {
      try PDFReportFormatter(generatedAt: DateParser.parse("08/03/2026"))
    }

    private func renderPDF(_ result: CalculationResult) throws -> Data {
      let rendered = try self.makePDFFormatter().render(result)
      switch rendered {
      case .binary(let data):
        return data
      case .text:
        XCTFail("Expected PDF binary output")
        return Data()
      }
    }

    private func extractPDFSnapshotText(from data: Data) throws -> String {
      let document = try XCTUnwrap(PDFDocument(data: data), "Unable to parse PDF data")
      let pages = (0 ..< document.pageCount).compactMap { pageIndex -> String? in
        guard let text = document.page(at: pageIndex)?.string else {
          return nil
        }
        return self.normalizeSnapshotText(text)
      }
      return pages.enumerated()
        .map { index, text in
          "--- PAGE \(index + 1) ---\n\(text)"
        }
        .joined(separator: "\n\n")
    }

    private func assertSnapshot(named name: String, actual: String) throws {
      let sourceRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      let sourceSnapshot = sourceRoot.appendingPathComponent("TestData/PDFSnapshots/\(name).txt")

      if self.recordPDFFixtures {
        try FileManager.default.createDirectory(
          at: sourceSnapshot.deletingLastPathComponent(),
          withIntermediateDirectories: true)
        try actual.write(to: sourceSnapshot, atomically: true, encoding: .utf8)
        return
      }

      if !FileManager.default.fileExists(atPath: sourceSnapshot.path) {
        try FileManager.default.createDirectory(
          at: sourceSnapshot.deletingLastPathComponent(),
          withIntermediateDirectories: true)
        try actual.write(to: sourceSnapshot, atomically: true, encoding: .utf8)
        XCTFail("Recorded missing PDF snapshot fixture at \(sourceSnapshot.path). Re-run tests.")
        return
      }

      let expected = try String(contentsOf: sourceSnapshot, encoding: .utf8)
      XCTAssertEqual(actual, expected, "PDF snapshot mismatch for \(name)")
    }

    private func normalizeSnapshotText(_ text: String) -> String {
      text
        .replacingOccurrences(of: "\r\n", with: "\n")
        .split(separator: "\n", omittingEmptySubsequences: false)
        .map { line in
          line.replacingOccurrences(of: "\\s+$", with: "", options: .regularExpression)
        }
        .joined(separator: "\n")
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }
  }
#endif
