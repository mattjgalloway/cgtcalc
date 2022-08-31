//
//  CalculatorTests.swift
//  CGTCalcCoreTests
//
//  Created by Matt Galloway on 09/06/2020.
//

@testable import CGTCalcCore
import XCTest

class CalculatorTests: XCTestCase {
  let logger = StubLogger()

  private struct TestData {
    let transactions: [Transaction]
    let assetEvents: [AssetEvent]
    let gains: [TaxYear: Decimal]
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
      XCTFail("Failed to calculate: \(error)")
    }
  }

  func testBasicSingleAsset() throws {
    let testData = TestData(
      transactions: [
        ModelCreation.transaction(.Sell, "28/11/2019", "Foo", "2234.0432", "4.6702", "12.5"),
        ModelCreation.transaction(.Buy, "28/08/2018", "Foo", "812.9", "4.1565", "12.5"),
        ModelCreation.transaction(.Buy, "01/03/2018", "Foo", "1421.1432", "3.6093", "2")
      ],
      assetEvents: [],
      gains: [
        TaxYear(yearEnding: 2020): Decimal(string: "1898")!
      ],
      shouldThrow: false)
    self.runTest(withData: testData)
  }

  func testAssetEventWithNoAcquisition() throws {
    let testData = TestData(
      transactions: [],
      assetEvents: [
        ModelCreation.assetEvent(.Dividend(Decimal(1), Decimal(1)), "01/01/2020", "Foo")
      ],
      gains: [:],
      shouldThrow: true)
    self.runTest(withData: testData)
  }

  func testAssetEventDividendTooLarge() throws {
    let testData = TestData(
      transactions: [
        ModelCreation.transaction(.Buy, "01/01/2020", "Foo", "90", "1", "12.5")
      ],
      assetEvents: [
        ModelCreation.assetEvent(.Dividend(Decimal(100), Decimal(1)), "02/01/2020", "Foo")
      ],
      gains: [:],
      shouldThrow: true)
    self.runTest(withData: testData)
  }

  func testAssetEventCapitalReturnTooLarge() throws {
    let testData = TestData(
      transactions: [
        ModelCreation.transaction(.Buy, "01/01/2020", "Foo", "90", "1", "12.5")
      ],
      assetEvents: [
        ModelCreation.assetEvent(.CapitalReturn(Decimal(100), Decimal(1)), "02/01/2020", "Foo")
      ],
      gains: [:],
      shouldThrow: true)
    self.runTest(withData: testData)
  }

  func testAssetEventDividendTooSmall() throws {
    let testData = TestData(
      transactions: [
        ModelCreation.transaction(.Buy, "01/01/2020", "Foo", "100", "1", "12.5")
      ],
      assetEvents: [
        ModelCreation.assetEvent(.Dividend(Decimal(90), Decimal(1)), "02/01/2020", "Foo")
      ],
      gains: [:],
      shouldThrow: true)
    self.runTest(withData: testData)
  }

  func testAssetEventCapitalReturnTooSmall() throws {
    let testData = TestData(
      transactions: [
        ModelCreation.transaction(.Buy, "01/01/2020", "Foo", "100", "1", "12.5")
      ],
      assetEvents: [
        ModelCreation.assetEvent(.CapitalReturn(Decimal(90), Decimal(1)), "02/01/2020", "Foo")
      ],
      gains: [:],
      shouldThrow: true)
    self.runTest(withData: testData)
  }

  func testAssetEventDividendNotMatchingAmount() throws {
    let testData = TestData(
      transactions: [
        ModelCreation.transaction(.Buy, "01/01/2020", "Foo", "10", "1", "12.5"),
        ModelCreation.transaction(.Buy, "03/01/2020", "Foo", "10", "1", "12.5")
      ],
      assetEvents: [
        ModelCreation.assetEvent(.Dividend(Decimal(20), Decimal(1)), "02/01/2020", "Foo")
      ],
      gains: [:],
      shouldThrow: true)
    self.runTest(withData: testData)
  }

  func testBedAndBreakfastEdges() throws {
    // Exactly 30 days
    let testData1 = TestData(
      transactions: [
        ModelCreation.transaction(.Buy, "01/01/2018", "Foo", "1", "10", "0"),
        ModelCreation.transaction(.Sell, "02/01/2018", "Foo", "1", "10", "0"),
        ModelCreation.transaction(.Buy, "01/02/2018", "Foo", "1", "1", "0")
      ],
      assetEvents: [],
      gains: [
        TaxYear(yearEnding: 2018): Decimal(string: "9")!
      ],
      shouldThrow: false)
    self.runTest(withData: testData1)

    // Exactly 31 days
    let testData2 = TestData(
      transactions: [
        ModelCreation.transaction(.Buy, "01/01/2018", "Foo", "1", "10", "0"),
        ModelCreation.transaction(.Sell, "02/01/2018", "Foo", "1", "10", "0"),
        ModelCreation.transaction(.Buy, "02/02/2018", "Foo", "1", "1", "0")
      ],
      assetEvents: [],
      gains: [
        TaxYear(yearEnding: 2018): Decimal(string: "0")!
      ],
      shouldThrow: false)
    self.runTest(withData: testData2)
  }

  func testSection104DisposeTooMuch() throws {
    let testData = TestData(
      transactions: [
        ModelCreation.transaction(.Buy, "01/01/2020", "Foo", "10", "1", "12.5"),
        ModelCreation.transaction(.Sell, "02/01/2018", "Foo", "1", "10", "0"),
        ModelCreation.transaction(.Sell, "03/01/2018", "Foo", "1", "10", "0")
      ],
      assetEvents: [],
      gains: [:],
      shouldThrow: true)
    self.runTest(withData: testData)
  }

  func testDateBefore20080406Throws() throws {
    let transaction = ModelCreation.transaction(.Buy, "05/04/2008", "Foo", "1", "1", "0")
    let input = CalculatorInput(transactions: [transaction], assetEvents: [])
    let calculator = try Calculator(input: input, logger: self.logger)
    XCTAssertThrowsError(try calculator.process())
  }

  func testCapitalReturnNotEnoughAcquisitionsThrows() throws {
    let testData = TestData(
      transactions: [
        ModelCreation.transaction(.Buy, "01/01/2018", "Foo", "10", "10", "0")
      ],
      assetEvents: [
        ModelCreation.assetEvent(.CapitalReturn(10, 1), "01/02/2018", "Foo"),
        ModelCreation.assetEvent(.CapitalReturn(10, 1), "01/03/2018", "Foo")
      ],
      gains: [:],
      shouldThrow: true)
    self.runTest(withData: testData)
  }

  func testSoldMoreThanOwnWithCapitalReturnEventThrows() throws {
    let testData = TestData(
      transactions: [
        ModelCreation.transaction(.Buy, "01/01/2018", "Foo", "10", "10", "0"),
        ModelCreation.transaction(.Sell, "01/02/2018", "Foo", "15", "10", "0")
      ],
      assetEvents: [
        ModelCreation.assetEvent(.CapitalReturn(10, 1), "01/03/2018", "Foo")
      ],
      gains: [:],
      shouldThrow: true)
    self.runTest(withData: testData)
  }

  func testSoldMoreThanOwnWithDividendEventThrows() throws {
    let testData = TestData(
      transactions: [
        ModelCreation.transaction(.Buy, "01/01/2018", "Foo", "10", "10", "0"),
        ModelCreation.transaction(.Sell, "01/02/2018", "Foo", "15", "10", "0")
      ],
      assetEvents: [
        ModelCreation.assetEvent(.Dividend(10, 1), "01/03/2018", "Foo")
      ],
      gains: [:],
      shouldThrow: true)
    self.runTest(withData: testData)
  }

  func testSoldNotAllBeforeCapitalReturn() throws {
    let testData = TestData(
      transactions: [
        ModelCreation.transaction(.Buy, "01/01/2018", "Foo", "10", "10", "0"),
        ModelCreation.transaction(.Sell, "01/02/2018", "Foo", "5", "10", "0")
      ],
      assetEvents: [
        ModelCreation.assetEvent(.CapitalReturn(5, 10), "01/03/2018", "Foo")
      ],
      gains: [
        TaxYear(yearEnding: 2018): Decimal(string: "5")!
      ],
      shouldThrow: false)
    self.runTest(withData: testData)
  }

  func testSoldNotAllBeforeDividend() throws {
    let testData = TestData(
      transactions: [
        ModelCreation.transaction(.Buy, "01/01/2018", "Foo", "10", "10", "0"),
        ModelCreation.transaction(.Sell, "01/02/2018", "Foo", "5", "10", "0")
      ],
      assetEvents: [
        ModelCreation.assetEvent(.Dividend(5, 10), "01/03/2018", "Foo")
      ],
      gains: [
        TaxYear(yearEnding: 2018): Decimal(string: "-5")!
      ],
      shouldThrow: false)
    self.runTest(withData: testData)
  }

  func testCapitalReturnEvent() throws {
    let testData = TestData(
      transactions: [
        ModelCreation.transaction(.Sell, "01/03/2018", "Foo", "2.0", "100.0", "0.0"),
        ModelCreation.transaction(.Buy, "01/01/2018", "Foo", "2.0", "100.0", "0.0")
      ],
      assetEvents: [
        ModelCreation.assetEvent(.CapitalReturn(2, 10), "01/02/2018", "Foo")
      ],
      gains: [
        TaxYear(yearEnding: 2018): Decimal(string: "10")!
      ],
      shouldThrow: false)
    self.runTest(withData: testData)
  }

  func testCapitalReturnEventSameDayCombine() throws {
    let testData = TestData(
      transactions: [
        ModelCreation.transaction(.Sell, "01/03/2018", "Foo", "2.0", "100.0", "0.0"),
        ModelCreation.transaction(.Buy, "01/01/2018", "Foo", "2.0", "100.0", "0.0")
      ],
      assetEvents: [
        ModelCreation.assetEvent(.CapitalReturn(1, 5), "01/02/2018", "Foo"),
        ModelCreation.assetEvent(.CapitalReturn(1, 5), "01/02/2018", "Foo")
      ],
      gains: [
        TaxYear(yearEnding: 2018): Decimal(string: "10")!
      ],
      shouldThrow: false)
    self.runTest(withData: testData)
  }

  func testDividendEvent() throws {
    let testData = TestData(
      transactions: [
        ModelCreation.transaction(.Sell, "01/03/2018", "Foo", "2.0", "100.0", "0.0"),
        ModelCreation.transaction(.Buy, "01/01/2018", "Foo", "2.0", "100.0", "0.0")
      ],
      assetEvents: [
        ModelCreation.assetEvent(.Dividend(2, 10), "01/02/2018", "Foo")
      ],
      gains: [
        TaxYear(yearEnding: 2018): Decimal(string: "-10")!
      ],
      shouldThrow: false)
    self.runTest(withData: testData)
  }

  func testCapitalReturnAndDividendEvents() throws {
    let testData = TestData(
      transactions: [
        ModelCreation.transaction(.Sell, "01/03/2018", "Foo", "2.0", "100.0", "0.0"),
        ModelCreation.transaction(.Buy, "01/01/2018", "Foo", "2.0", "100.0", "0.0")
      ],
      assetEvents: [
        ModelCreation.assetEvent(.CapitalReturn(2, 5), "01/02/2018", "Foo"),
        ModelCreation.assetEvent(.Dividend(2, 10), "01/02/2018", "Foo")
      ],
      gains: [
        TaxYear(yearEnding: 2018): Decimal(string: "-5")!
      ],
      shouldThrow: false)
    self.runTest(withData: testData)
  }
}
