//
//  SubTransactionTests.swift
//  CGTCalcCoreTests
//
//  Created by Matt Galloway on 09/06/2020.
//

import XCTest
@testable import CGTCalcCore

class SubTransactionTests: XCTestCase {

  func testSplitSuccess() throws {
    let transaction = Transaction(
      id: 1,
      kind: .Buy,
      date: DateCreation.date(fromString: "15/08/2020"),
      asset: "Foo",
      amount: Decimal(string: "12.345")!,
      price: Decimal(string: "1.2345")!,
      expenses: Decimal(string: "12.5")!)
    let acquisition = SubTransaction(transaction: transaction)
    let splitAmount = Decimal(string: "2.123")!
    let remainder = try acquisition.split(withAmount: splitAmount)
    XCTAssertEqual(acquisition.amount, Decimal(string: "10.222"))
    XCTAssertEqual(remainder.amount, splitAmount)
  }

  func testSplitTooMuchFails() throws {
    let transaction = Transaction(
      id: 1,
      kind: .Buy,
      date: DateCreation.date(fromString: "15/08/2020"),
      asset: "Foo",
      amount: Decimal(string: "12.345")!,
      price: Decimal(string: "1.2345")!,
      expenses: Decimal(string: "12.5")!)
    let acquisition = SubTransaction(transaction: transaction)
    let splitAmount = Decimal(string: "100")!
    XCTAssertThrowsError(try acquisition.split(withAmount: splitAmount))
  }

}
