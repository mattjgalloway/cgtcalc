//
//  CalculatorTests.swift
//  CGTCalcCoreTests
//
//  Created by Matt Galloway on 09/06/2020.
//

import XCTest
@testable import CGTCalcCore

class CalculatorTests: XCTestCase {

  let logger = StubLogger()

  private struct TestData {
    let transactions: [Transaction]
    let assetEvents: [AssetEvent]
    let gains: [TaxYear:Decimal]
    let shouldThrow: Bool
  }

  private func runTest(withData data: TestData) {
    do {
      let input = CalculatorInput(transactions: data.transactions, assetEvents: data.assetEvents)
      let calculator = try Calculator(input: input, logger: self.logger)

      let result: CalculatorResult
      if data.shouldThrow {
        XCTAssertThrowsError(try calculator.process())
        return
      } else {
        result = try calculator.process()
      }

      XCTAssertEqual(result.taxYearSummaries.count, data.gains.count)
      result.taxYearSummaries.forEach { taxYearSummary in
        guard let gain = data.gains[taxYearSummary.taxYear] else {
          XCTFail("Unexpected tax year found")
          return
        }
        XCTAssertEqual(gain, taxYearSummary.gain)
      }
    } catch {
      XCTFail("Failed to calculate")
    }
  }

  func testBasicSingleAsset() throws {
    let testData = TestData(
      transactions: [
        ModelCreation.transaction(1, .Sell, "28/11/2019", "Foo", "2234.0432", "4.6702", "12.5"),
        ModelCreation.transaction(2, .Buy, "28/08/2018", "Foo", "812.9", "4.1565", "12.5"),
        ModelCreation.transaction(3, .Buy, "01/03/2018", "Foo", "1421.1432", "3.6093", "2"),
      ],
      assetEvents: [],
      gains: [
        TaxYear(year: 2020): Decimal(string: "1898")!,
      ],
      shouldThrow: false
    )
    self.runTest(withData: testData)
  }

  func testAssetEventWithNoAcquisition() throws {
    let testData = TestData(
      transactions: [],
      assetEvents: [
        ModelCreation.assetEvent(1, .Dividend(Decimal(1), Decimal(1)), "01/01/2020", "Foo")
      ],
      gains: [:],
      shouldThrow: true
    )
    self.runTest(withData: testData)
  }

  func testDateBefore20080406Throws() throws {
    let transaction = ModelCreation.transaction(1, .Buy, "05/04/2008", "Foo", "1", "1", "0")
    let input = CalculatorInput(transactions: [transaction], assetEvents: [])
    let calculator = try Calculator(input: input, logger: self.logger)
    XCTAssertThrowsError(try calculator.process())
  }

}
