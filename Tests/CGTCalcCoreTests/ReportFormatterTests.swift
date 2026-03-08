@testable import CGTCalcCore
import XCTest

final class ReportFormatterTests: XCTestCase {
  func testTextReportFormatterRendersText() throws {
    let result = ReportFormatterFixtureFactory.makeResult()
    let rendered = try TextReportFormatter().render(result)

    switch rendered {
    case .text(let output):
      XCTAssertTrue(output.contains("# SUMMARY"))
      XCTAssertTrue(output.contains("TAX RETURN INFORMATION"))
    case .binary:
      XCTFail("Expected text output")
    }
  }
}
