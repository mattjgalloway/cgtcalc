//
//  TextPresenterTests.swift
//  CGTCalcCoreTests
//
//  Created by Matt Galloway on 10/06/2020.
//

import XCTest
@testable import CGTCalcCore

class TextPresenterTests: XCTestCase {

  func testFailsWhenTaxYearHasNoRates() throws {
    let acquisition = ModelCreation.transaction(1, .Buy, "01/01/2000", "Foo", "1000", "1", "0")
    let acquisitionSub = SubTransaction(transaction: acquisition)
    let disposal = ModelCreation.transaction(5, .Sell, "01/01/2000", "Foo", "1000", "1", "0")
    let disposalSub = SubTransaction(transaction: disposal)
    let disposalMatch = DisposalMatch(kind: .SameDay(acquisitionSub), disposal: disposalSub)
    let result = CalculatorResult(disposalMatches: [disposalMatch])
    let sut = TextPresenter(result: result)
    XCTAssertThrowsError(try sut.process())
  }

}
