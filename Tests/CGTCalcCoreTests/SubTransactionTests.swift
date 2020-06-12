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
    let transaction = ModelCreation.transaction(1, .Buy, "15/08/2020", "Foo", "12.345", "1.2345", "12.5")
    let acquisition = SubTransaction(transaction: transaction)
    let splitAmount = Decimal(string: "2.123")!
    let remainder = try acquisition.split(withAmount: splitAmount)
    XCTAssertEqual(acquisition.amount, splitAmount)
    XCTAssertEqual(remainder.amount, Decimal(string: "10.222"))
  }

  func testSplitTooMuchFails() throws {
    let transaction = ModelCreation.transaction(1, .Buy, "15/08/2020", "Foo", "12.345", "1.2345", "12.5")
    let acquisition = SubTransaction(transaction: transaction)
    let splitAmount = Decimal(string: "100")!
    XCTAssertThrowsError(try acquisition.split(withAmount: splitAmount))
  }

  func testOffsetWorks() throws {
    let transaction = ModelCreation.transaction(1, .Buy, "15/08/2020", "Foo", "10", "100.0", "12.5")
    let acquisition = SubTransaction(transaction: transaction)
    XCTAssertEqual(acquisition.price, Decimal(string: "100.0")!)
    XCTAssertEqual(acquisition.value, Decimal(string: "1000.0")!)
    XCTAssertEqual(acquisition.offset, Decimal.zero)

    acquisition.addOffset(amount: Decimal(string: "10.0")!)
    XCTAssertEqual(acquisition.price, Decimal(string: "101.0")!)
    XCTAssertEqual(acquisition.value, Decimal(string: "1010.0")!)
    XCTAssertEqual(acquisition.offset, Decimal(string: "10.0")!)

    acquisition.addOffset(amount: Decimal(string: "93.982")!)
    XCTAssertEqual(acquisition.price, Decimal(string: "110.3982")!)
    XCTAssertEqual(acquisition.value, Decimal(string: "1103.982")!)
    XCTAssertEqual(acquisition.offset, Decimal(string: "103.982")!)

    acquisition.subtractOffset(amount: Decimal(string: "10.0")!)
    XCTAssertEqual(acquisition.price, Decimal(string: "109.3982")!)
    XCTAssertEqual(acquisition.value, Decimal(string: "1093.982")!)
    XCTAssertEqual(acquisition.offset, Decimal(string: "93.982.0")!)

    acquisition.subtractOffset(amount: Decimal(string: "93.982")!)
    XCTAssertEqual(acquisition.price, Decimal(string: "100.0")!)
    XCTAssertEqual(acquisition.value, Decimal(string: "1000.0")!)
    XCTAssertEqual(acquisition.offset, Decimal.zero)
  }

  func testOffsetAndSplitWorks() throws {
    let transaction = ModelCreation.transaction(1, .Buy, "15/08/2020", "Foo", "10", "100.0", "12.5")
    let acquisition = SubTransaction(transaction: transaction)
    acquisition.addOffset(amount: Decimal(string: "10.0")!)
    let remainder = try acquisition.split(withAmount: Decimal(4))

    XCTAssertEqual(acquisition.amount, Decimal(4))
    XCTAssertEqual(remainder.amount, Decimal(6))
    XCTAssertEqual(acquisition.value, Decimal(404))
    XCTAssertEqual(remainder.value, Decimal(606))
    XCTAssertEqual(acquisition.price, Decimal(101))
    XCTAssertEqual(remainder.price, Decimal(101))
  }

}
