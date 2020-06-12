//
//  DescriptionTests.swift
//  CGTCalcCoreTests
//
//  Created by Matt Galloway on 10/06/2020.
//

import XCTest
@testable import CGTCalcCore

class DescriptionTests: XCTestCase {

  func testAssetResult() throws {
    let sut = AssetResult(asset: "Foo", disposalMatches: [])
    let description = sut.description
    let expected = "<AssetResult: asset=Foo, disposalMatches=[]>"
    XCTAssertEqual(description, expected)
  }

  func testTaxYear() throws {
    let sut = TaxYear(year: 2020)
    let description = sut.description
    let expected = "2019/2020"
    XCTAssertEqual(description, expected)
  }

  func testTransaction() throws {
    let sut = ModelCreation.transaction(1, .Buy, "01/01/2020", "Foo", "1234", "1.23", "12.5")
    let description = sut.description
    let expected = "<Transaction: id=1, kind=Buy, date=2020-01-01 00:00:00 +0000, asset=Foo, amount=1234, price=1.23, expenses=12.5>"
    XCTAssertEqual(description, expected)
  }

  func testSubTransaction() throws {
    let transaction = ModelCreation.transaction(1, .Buy, "01/01/2020", "Foo", "1234", "1.23", "12.5")
    let sut = SubTransaction(transaction: transaction)
    let description = sut.description
    let expected = "<SubTransaction: transaction=<Transaction: id=1, kind=Buy, date=2020-01-01 00:00:00 +0000, asset=Foo, amount=1234, price=1.23, expenses=12.5>, amount=1234, underlyingPrice=1.23, price=1.23, expenses=12.5, offset=0>"
    XCTAssertEqual(description, expected)
  }

  func testDisposalMatch() throws {
    let acquisition = ModelCreation.transaction(1, .Buy, "01/01/2020", "Foo", "1234", "1.23", "12.5")
    let acquisitionSub = SubTransaction(transaction: acquisition)
    let disposal = ModelCreation.transaction(2, .Sell, "01/01/2020", "Foo", "1234", "1.29", "2")
    let disposalSub = SubTransaction(transaction: disposal)
    let sut = DisposalMatch(kind: .SameDay(acquisitionSub), disposal: disposalSub)
    let description = sut.description
    let expected = "<DisposalMatch: kind=SameDay(<SubTransaction: transaction=<Transaction: id=1, kind=Buy, date=2020-01-01 00:00:00 +0000, asset=Foo, amount=1234, price=1.23, expenses=12.5>, amount=1234, underlyingPrice=1.23, price=1.23, expenses=12.5, offset=0>), asset=Foo, date=2020-01-01 00:00:00 +0000, taxYear=2019/2020, disposal=<SubTransaction: transaction=<Transaction: id=2, kind=Sell, date=2020-01-01 00:00:00 +0000, asset=Foo, amount=1234, price=1.29, expenses=2>, amount=1234, underlyingPrice=1.29, price=1.29, expenses=2, offset=0>, gain=59.54>"
    XCTAssertEqual(description, expected)
  }

  func testSection104HoldingState() throws {
    let sut = Section104Holding.State(amount: Decimal(string: "1000")!, cost: Decimal(string: "2313.23")!)
    let description = sut.description
    let expected = "<State: amount=1000, cost=2313.23, costBasis=2.31323>"
    XCTAssertEqual(description, expected)
  }

}
