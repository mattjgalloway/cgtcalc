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

  func testAssetEventDividendTooLarge() throws {
    let testData = TestData(
      transactions: [
        ModelCreation.transaction(2, .Buy, "01/01/2020", "Foo", "90", "1", "12.5"),
      ],
      assetEvents: [
        ModelCreation.assetEvent(1, .Dividend(Decimal(100), Decimal(1)), "02/01/2020", "Foo")
      ],
      gains: [:],
      shouldThrow: true
    )
    self.runTest(withData: testData)
  }

  func testAssetEventCapitalReturnTooLarge() throws {
    let testData = TestData(
      transactions: [
        ModelCreation.transaction(2, .Buy, "01/01/2020", "Foo", "90", "1", "12.5"),
      ],
      assetEvents: [
        ModelCreation.assetEvent(1, .CapitalReturn(Decimal(100), Decimal(1)), "02/01/2020", "Foo")
      ],
      gains: [:],
      shouldThrow: true
    )
    self.runTest(withData: testData)
  }

  func testAssetEventDividendTooSmall() throws {
    let testData = TestData(
      transactions: [
        ModelCreation.transaction(2, .Buy, "01/01/2020", "Foo", "100", "1", "12.5"),
      ],
      assetEvents: [
        ModelCreation.assetEvent(1, .Dividend(Decimal(90), Decimal(1)), "02/01/2020", "Foo")
      ],
      gains: [:],
      shouldThrow: true
    )
    self.runTest(withData: testData)
  }

  func testAssetEventCapitalReturnTooSmall() throws {
    let testData = TestData(
      transactions: [
        ModelCreation.transaction(2, .Buy, "01/01/2020", "Foo", "100", "1", "12.5"),
      ],
      assetEvents: [
        ModelCreation.assetEvent(1, .CapitalReturn(Decimal(90), Decimal(1)), "02/01/2020", "Foo")
      ],
      gains: [:],
      shouldThrow: true
    )
    self.runTest(withData: testData)
  }

  func testAssetEventDividendNotMatchingAmount() throws {
    let testData = TestData(
      transactions: [
        ModelCreation.transaction(2, .Buy, "01/01/2020", "Foo", "10", "1", "12.5"),
        ModelCreation.transaction(3, .Buy, "03/01/2020", "Foo", "10", "1", "12.5"),
      ],
      assetEvents: [
        ModelCreation.assetEvent(1, .Dividend(Decimal(20), Decimal(1)), "02/01/2020", "Foo")
      ],
      gains: [:],
      shouldThrow: true
    )
    self.runTest(withData: testData)
  }

  func testBedAndBreakfastEdges() throws {
    // Exactly 30 days
    let testData1 = TestData(
      transactions: [
        ModelCreation.transaction(1, .Buy, "01/01/2018", "Foo", "1", "10", "0"),
        ModelCreation.transaction(2, .Sell, "02/01/2018", "Foo", "1", "10", "0"),
        ModelCreation.transaction(3, .Buy, "01/02/2018", "Foo", "1", "1", "0"),
      ],
      assetEvents: [],
      gains: [
        TaxYear(year: 2018): Decimal(string: "9")!,
      ],
      shouldThrow: false
    )
    self.runTest(withData: testData1)

    // Exactly 31 days
    let testData2 = TestData(
      transactions: [
        ModelCreation.transaction(1, .Buy, "01/01/2018", "Foo", "1", "10", "0"),
        ModelCreation.transaction(2, .Sell, "02/01/2018", "Foo", "1", "10", "0"),
        ModelCreation.transaction(3, .Buy, "02/02/2018", "Foo", "1", "1", "0"),
      ],
      assetEvents: [],
      gains: [
        TaxYear(year: 2018): Decimal(string: "0")!,
      ],
      shouldThrow: false
    )
    self.runTest(withData: testData2)
  }

  func testDateBefore20080406Throws() throws {
    let transaction = ModelCreation.transaction(1, .Buy, "05/04/2008", "Foo", "1", "1", "0")
    let input = CalculatorInput(transactions: [transaction], assetEvents: [])
    let calculator = try Calculator(input: input, logger: self.logger)
    XCTAssertThrowsError(try calculator.process())
  }

}
