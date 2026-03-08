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
