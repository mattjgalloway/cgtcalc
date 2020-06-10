//
//  DefaultParserTests.swift
//  CGTCalcCoreTests
//
//  Created by Matt Galloway on 09/06/2020.
//

import XCTest
@testable import CGTCalcCore

class DefaultParserTests: XCTestCase {

  func testParseBuyTransactionSuccess() throws {
    let sut = DefaultParser()
    let data = "BUY 15/08/2020 Foo 12.345 1.2345 12.5"
    let transaction = try sut.transaction(fromData: data)
    XCTAssertNotNil(transaction)
    XCTAssertEqual(transaction!.kind, .Buy)
    XCTAssertEqual(transaction!.date, Date(timeIntervalSince1970: 1597449600))
    XCTAssertEqual(transaction!.asset, "Foo")
    XCTAssertEqual(transaction!.amount, Decimal(12.345))
    XCTAssertEqual(transaction!.price, Decimal(1.2345))
    XCTAssertEqual(transaction!.expenses, Decimal(12.5))
  }

  func testParseSellTransactionSuccess() throws {
    let sut = DefaultParser()
    let data = "SELL 15/08/2020 Foo 12.345 1.2345 12.5"
    let transaction = try sut.transaction(fromData: data)
    XCTAssertNotNil(transaction)
    XCTAssertEqual(transaction!.kind, .Sell)
    XCTAssertEqual(transaction!.date, Date(timeIntervalSince1970: 1597449600))
    XCTAssertEqual(transaction!.asset, "Foo")
    XCTAssertEqual(transaction!.amount, Decimal(12.345))
    XCTAssertEqual(transaction!.price, Decimal(1.2345))
    XCTAssertEqual(transaction!.expenses, Decimal(12.5))
  }

  func testParseSection104AdjustTransactionSuccess() throws {
    let sut = DefaultParser()
    let data = "ADJ 15/08/2020 Foo 0 0 100"
    let transaction = try sut.transaction(fromData: data)
    XCTAssertNotNil(transaction)
    XCTAssertEqual(transaction!.kind, .Section104Adjust)
    XCTAssertEqual(transaction!.date, Date(timeIntervalSince1970: 1597449600))
    XCTAssertEqual(transaction!.asset, "Foo")
    XCTAssertEqual(transaction!.amount, Decimal(0))
    XCTAssertEqual(transaction!.price, Decimal(0))
    XCTAssertEqual(transaction!.expenses, Decimal(100))
  }

  func testParseCommentSuccess() throws {
    let sut = DefaultParser()
    let data = "# THIS IS A COMMENT"
    let transaction = try sut.transaction(fromData: data)
    XCTAssertNil(transaction)
  }

  func testParseIncorrectKindFails() throws {
    let sut = DefaultParser()
    let data = "FOOBAR 08/15/2020 Foo 12.345 1.2345 12.5"
    XCTAssertThrowsError(try sut.transaction(fromData: data))
  }

  func testParseIncorrectDateFormatFails() throws {
    let sut = DefaultParser()
    let data = "BUY 08/15/2020 Foo 12.345 1.2345 12.5"
    XCTAssertThrowsError(try sut.transaction(fromData: data))
  }

  func testParseIncorrectNumberOfFieldsFails() throws {
    let sut = DefaultParser()
    let data = "BUY 15/08/2020 Foo 12.345 1.2345"
    XCTAssertThrowsError(try sut.transaction(fromData: data))
  }

  func testParseIncorrectNumberFormatFails() throws {
    let sut = DefaultParser()
    let data = "BUY 15/08/2020 Foo abc def 12.5"
    XCTAssertThrowsError(try sut.transaction(fromData: data))
  }

}
