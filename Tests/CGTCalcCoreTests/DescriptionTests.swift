//
//  DescriptionTests.swift
//  CGTCalcCoreTests
//
//  Created by Matt Galloway on 10/06/2020.
//

@testable import CGTCalcCore
import XCTest

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
    let sut = ModelCreation.transaction(.Buy, "01/01/2020", "Foo", "1234", "1.23", "12.5")
    let description = sut.description
    let expected =
      "<Transaction: kind=Buy, date=2020-01-01 00:00:00 +0000, asset=Foo, amount=1234, price=1.23, expenses=12.5, groupedTransactions=[]>"
    XCTAssertEqual(description, expected)
  }

  func testTransactionToMatch() throws {
    let transaction = ModelCreation.transaction(.Buy, "01/01/2020", "Foo", "1234", "1.23", "12.5")
    let sut = TransactionToMatch(transaction: transaction)
    let description = sut.description
    let expected =
      "<TransactionToMatch: transaction=<Transaction: kind=Buy, date=2020-01-01 00:00:00 +0000, asset=Foo, amount=1234, price=1.23, expenses=12.5, groupedTransactions=[]>, amount=1234, underlyingPrice=1.23, price=1.23, expenses=12.5, offset=0>"
    XCTAssertEqual(description, expected)
  }

  func testDisposalMatch() throws {
    let acquisition = ModelCreation.transaction(.Buy, "01/01/2020", "Foo", "1234", "1.23", "12.5")
    let acquisitionSub = TransactionToMatch(transaction: acquisition)
    let disposal = ModelCreation.transaction(.Sell, "01/01/2020", "Foo", "1234", "1.29", "2")
    let disposalSub = TransactionToMatch(transaction: disposal)
    let sut = DisposalMatch(kind: .SameDay(acquisitionSub), disposal: disposalSub, restructureMultiplier: Decimal(1))
    let description = sut.description
    let expected =
      "<DisposalMatch: kind=SameDay(<TransactionToMatch: transaction=<Transaction: kind=Buy, date=2020-01-01 00:00:00 +0000, asset=Foo, amount=1234, price=1.23, expenses=12.5, groupedTransactions=[]>, amount=1234, underlyingPrice=1.23, price=1.23, expenses=12.5, offset=0>), asset=Foo, date=2020-01-01 00:00:00 +0000, taxYear=2019/2020, disposal=<TransactionToMatch: transaction=<Transaction: kind=Sell, date=2020-01-01 00:00:00 +0000, asset=Foo, amount=1234, price=1.29, expenses=2, groupedTransactions=[]>, amount=1234, underlyingPrice=1.29, price=1.29, expenses=2, offset=0>, gain=59.54, restructureMultiplier=1>"
    XCTAssertEqual(description, expected)
  }

  func testSection104HoldingState() throws {
    let sut = Section104Holding.State(amount: Decimal(string: "1000")!, cost: Decimal(string: "2313.23")!)
    let description = sut.description
    let expected = "<State: amount=1000, cost=2313.23, costBasis=2.31323>"
    XCTAssertEqual(description, expected)
  }
}
