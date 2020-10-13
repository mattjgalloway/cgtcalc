//
//  CalculatorResultTests.swift
//  CGTCalcCoreTests
//
//  Created by Matt Galloway on 10/06/2020.
//

@testable import CGTCalcCore
import XCTest

class CalculatorResultTests: XCTestCase {
  func testFailsWhenTaxYearHasNoRates() throws {
    let acquisition = ModelCreation.transaction(.Buy, "01/01/2000", "Foo", "1000", "1", "0")
    let acquisitionSub = TransactionToMatch(transaction: acquisition)
    let disposal = ModelCreation.transaction(.Sell, "01/01/2000", "Foo", "1000", "1", "0")
    let disposalSub = TransactionToMatch(transaction: disposal)
    let disposalMatch = DisposalMatch(
      kind: .SameDay(acquisitionSub),
      disposal: disposalSub,
      restructureMultiplier: Decimal(1))
    let input = CalculatorInput(transactions: [acquisition, disposal], assetEvents: [])
    XCTAssertThrowsError(try CalculatorResult(input: input, disposalMatches: [disposalMatch]))
  }
}
