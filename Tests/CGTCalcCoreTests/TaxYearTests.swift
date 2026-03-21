@testable import CGTCalcCore
import XCTest

/// Tests for TaxYear
final class TaxYearTests: XCTestCase {
  private func date(_ value: String) throws -> Date {
    try DateParser.parse(value)
  }

  func testTaxYearFromDate_BeforeApril6() throws {
    // April 5, 2020 should be tax year 2019/2020
    let parsedDate = try self.date("05/04/2020")
    let taxYear = TaxYear.from(date: parsedDate)
    XCTAssertEqual(taxYear.startYear, 2019)
    XCTAssertEqual(taxYear.label, "2019/2020")
  }

  func testTaxYearFromDate_AfterApril6() throws {
    // April 6, 2020 should be tax year 2020/2021
    let parsedDate = try self.date("06/04/2020")
    let taxYear = TaxYear.from(date: parsedDate)
    XCTAssertEqual(taxYear.startYear, 2020)
    XCTAssertEqual(taxYear.label, "2020/2021")
  }

  func testTaxYearFromDate_MidYear() throws {
    // Mid-year should be in the correct tax year
    // January 2020 is in tax year 2019/2020
    let parsedDate = try self.date("15/01/2020")
    let taxYear = TaxYear.from(date: parsedDate)
    XCTAssertEqual(taxYear.startYear, 2019)
    XCTAssertEqual(taxYear.label, "2019/2020")
  }

  func testTaxYearFromDate_April5Boundary() throws {
    // Test exact boundary: April 5
    let parsedDate = try self.date("05/04/2021")
    let taxYear = TaxYear.from(date: parsedDate)
    XCTAssertEqual(taxYear.startYear, 2020)
  }

  func testTaxYearFromDate_April6Boundary() throws {
    // Test exact boundary: April 6
    let parsedDate = try self.date("06/04/2021")
    let taxYear = TaxYear.from(date: parsedDate)
    XCTAssertEqual(taxYear.startYear, 2021)
  }

  func testTaxYearContains() throws {
    let taxYear = TaxYear(startYear: 2019)

    // Start date (April 6) should be included
    let startDate = try self.date("06/04/2019")
    XCTAssertTrue(taxYear.contains(startDate))

    // End date (April 5) should be included
    let endDate = try self.date("05/04/2020")
    XCTAssertTrue(taxYear.contains(endDate))

    // Mid-year should be included
    let midDate = try self.date("01/01/2020")
    XCTAssertTrue(taxYear.contains(midDate))

    // Before tax year should not be included
    let beforeDate = try self.date("05/04/2019")
    XCTAssertFalse(taxYear.contains(beforeDate))

    // After tax year should not be included
    let afterDate = try self.date("06/04/2020")
    XCTAssertFalse(taxYear.contains(afterDate))
  }

  func testTaxYearComparison() {
    let taxYear2019 = TaxYear(startYear: 2019)
    let taxYear2020 = TaxYear(startYear: 2020)

    XCTAssertTrue(taxYear2019 < taxYear2020)
    XCTAssertFalse(taxYear2020 < taxYear2019)
  }

  func testTaxYearLabel() {
    let taxYear = TaxYear(startYear: 2019)
    XCTAssertEqual(taxYear.label, "2019/2020")
  }

  func testTaxYearStartDate() throws {
    let taxYear = TaxYear(startYear: 2019)
    let expected = try self.date("06/04/2019")
    XCTAssertEqual(taxYear.startDate, expected)
  }

  func testTaxYearEndDate() throws {
    let taxYear = TaxYear(startYear: 2019)
    let expected = try self.date("05/04/2020")
    XCTAssertEqual(taxYear.endDate, expected)
  }

  func testTaxRatesInclude2026_2027() throws {
    let rates = try TaxRateLookup.rates(for: TaxYear(startYear: 2026))
    XCTAssertEqual(rates.exemption, 3000)
  }
}
