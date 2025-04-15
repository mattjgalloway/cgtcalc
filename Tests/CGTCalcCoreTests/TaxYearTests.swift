//
//  TaxYearTests.swift
//  CGTCalcCoreTests
//
//  Created by Matt Galloway on 09/06/2020.
//

@testable import CGTCalcCore
import XCTest

class TaxYearTests: XCTestCase {
  private func dateFromComponents(year: Int, month: Int, day: Int) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    let calendar = Calendar(identifier: .gregorian)
    return calendar.date(from: components)!
  }

  func testDatesToTaxYearCorrect() throws {
    do {
      let date = self.dateFromComponents(year: 2015, month: 01, day: 01)
      let taxYear = TaxYear(containingDate: date)
      XCTAssertEqual(taxYear.year, 2015)
    }

    do {
      let date = self.dateFromComponents(year: 2015, month: 04, day: 05)
      let taxYear = TaxYear(containingDate: date)
      XCTAssertEqual(taxYear.year, 2015)
    }

    do {
      let date = self.dateFromComponents(year: 2015, month: 04, day: 06)
      let taxYear = TaxYear(containingDate: date)
      XCTAssertEqual(taxYear.year, 2016)
    }

    do {
      let date = self.dateFromComponents(year: 2019, month: 08, day: 01)
      let taxYear = TaxYear(containingDate: date)
      XCTAssertEqual(taxYear.year, 2020)
    }

    do {
      let date = self.dateFromComponents(year: 2020, month: 01, day: 01)
      let taxYear = TaxYear(containingDate: date)
      XCTAssertEqual(taxYear.year, 2020)
    }
  }

  func testTaxYearStringCorrect() throws {
    do {
      let taxYear = TaxYear(yearEnding: 2019)
      XCTAssertEqual(taxYear.string, "2018/2019")
    }

    do {
      let taxYear = TaxYear(yearEnding: 2020)
      XCTAssertEqual(taxYear.string, "2019/2020")
    }
  }

  func testTaxYearCompare() throws {
    let taxYear1 = TaxYear(yearEnding: 2019)
    let taxYear2 = TaxYear(yearEnding: 2020)
    let taxYear3 = TaxYear(yearEnding: 2020)
    XCTAssertLessThan(taxYear1, taxYear2)
    XCTAssertGreaterThan(taxYear2, taxYear1)
    XCTAssertNotEqual(taxYear1, taxYear2)
    XCTAssertEqual(taxYear2, taxYear3)
  }

  func testTaxYearRatesAvailable() throws {
    for year in 2014 ... 2026 {
      XCTAssertNotNil(TaxYear.rates[TaxYear(yearEnding: year)])
    }
  }
}
