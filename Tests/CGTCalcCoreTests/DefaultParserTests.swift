//
//  DefaultParserTests.swift
//  CGTCalcCoreTests
//
//  Created by Matt Galloway on 09/06/2020.
//

@testable import CGTCalcCore
import XCTest

class DefaultParserTests: XCTestCase {
  func testParseBuyTransactionSuccess() throws {
    let sut = DefaultParser()
    let data = "BUY 15/08/2020 Foo 12.345 1.2345 12.5"
    let transaction = try sut.transaction(fromData: Substring(data))
    XCTAssertNotNil(transaction)
    XCTAssertEqual(transaction?.kind, .Buy)
    XCTAssertEqual(transaction?.date, Date(timeIntervalSince1970: 1597449600))
    XCTAssertEqual(transaction?.asset, "Foo")
    XCTAssertEqual(transaction?.amount, Decimal(12.345))
    XCTAssertEqual(transaction?.price, Decimal(1.2345))
    XCTAssertEqual(transaction?.expenses, Decimal(12.5))
  }

  func testParseSellTransactionSuccess() throws {
    let sut = DefaultParser()
    let data = "SELL 15/08/2020 Foo 12.345 1.2345 12.5"
    let transaction = try sut.transaction(fromData: Substring(data))
    XCTAssertNotNil(transaction)
    XCTAssertEqual(transaction?.kind, .Sell)
    XCTAssertEqual(transaction?.date, Date(timeIntervalSince1970: 1597449600))
    XCTAssertEqual(transaction?.asset, "Foo")
    XCTAssertEqual(transaction?.amount, Decimal(12.345))
    XCTAssertEqual(transaction?.price, Decimal(1.2345))
    XCTAssertEqual(transaction?.expenses, Decimal(12.5))
  }

  func testParseStripsTrailingWhitespace() throws {
    let sut = DefaultParser()
    let data = "BUY 15/08/2020 Foo 12.345 1.2345 12.5   \t\t   "
    let transaction = try sut.transaction(fromData: Substring(data))
    XCTAssertNotNil(transaction)
    XCTAssertEqual(transaction?.kind, .Buy)
    XCTAssertEqual(transaction?.date, Date(timeIntervalSince1970: 1597449600))
    XCTAssertEqual(transaction?.asset, "Foo")
    XCTAssertEqual(transaction?.amount, Decimal(12.345))
    XCTAssertEqual(transaction?.price, Decimal(1.2345))
    XCTAssertEqual(transaction?.expenses, Decimal(12.5))
  }

  func testParseAllowsMultipleWhitespace() throws {
    let sut = DefaultParser()
    let data = "BUY     15/08/2020    Foo   12.345  1.2345 12.5"
    let transaction = try sut.transaction(fromData: Substring(data))
    XCTAssertNotNil(transaction)
    XCTAssertEqual(transaction?.kind, .Buy)
    XCTAssertEqual(transaction?.date, Date(timeIntervalSince1970: 1597449600))
    XCTAssertEqual(transaction?.asset, "Foo")
    XCTAssertEqual(transaction?.amount, Decimal(12.345))
    XCTAssertEqual(transaction?.price, Decimal(1.2345))
    XCTAssertEqual(transaction?.expenses, Decimal(12.5))
  }

  func testParseCapitalReturnEventSuccess() throws {
    let sut = DefaultParser()
    let data = "CAPRETURN 15/08/2020 Foo 1.234 100"
    let transaction = try sut.assetEvent(fromData: Substring(data))
    XCTAssertNotNil(transaction)
    XCTAssertEqual(transaction?.kind, .CapitalReturn(Decimal(1.234), Decimal(100)))
    XCTAssertEqual(transaction?.date, Date(timeIntervalSince1970: 1597449600))
    XCTAssertEqual(transaction?.asset, "Foo")
  }

  func testParseDividendEventSuccess() throws {
    let sut = DefaultParser()
    let data = "DIVIDEND 15/08/2020 Foo 1.234 100"
    let transaction = try sut.assetEvent(fromData: Substring(data))
    XCTAssertNotNil(transaction)
    XCTAssertEqual(transaction?.kind, .Dividend(Decimal(1.234), Decimal(100)))
    XCTAssertEqual(transaction?.date, Date(timeIntervalSince1970: 1597449600))
    XCTAssertEqual(transaction?.asset, "Foo")
  }

  func testParseSplitEventSuccess() throws {
    let sut = DefaultParser()
    let data = "SPLIT 15/08/2020 Foo 10"
    let transaction = try sut.assetEvent(fromData: Substring(data))
    XCTAssertNotNil(transaction)
    XCTAssertEqual(transaction?.kind, .Split(Decimal(10)))
    XCTAssertEqual(transaction?.date, Date(timeIntervalSince1970: 1597449600))
    XCTAssertEqual(transaction?.asset, "Foo")
  }

  func testParseUnsplitEventSuccess() throws {
    let sut = DefaultParser()
    let data = "UNSPLIT 15/08/2020 Foo 10"
    let transaction = try sut.assetEvent(fromData: Substring(data))
    XCTAssertNotNil(transaction)
    XCTAssertEqual(transaction?.kind, .Unsplit(Decimal(10)))
    XCTAssertEqual(transaction?.date, Date(timeIntervalSince1970: 1597449600))
    XCTAssertEqual(transaction?.asset, "Foo")
  }

  func testParseCommentSuccess() throws {
    let sut = DefaultParser()
    let data = "# THIS IS A COMMENT"
    let transaction = try sut.transaction(fromData: Substring(data))
    XCTAssertNil(transaction)
  }

  func testParseTransactionIncorrectKindFails() throws {
    let sut = DefaultParser()
    let data = "FOOBAR 08/15/2020 Foo 12.345 1.2345 12.5"
    let transaction = try sut.transaction(fromData: Substring(data))
    XCTAssertNil(transaction)
  }

  func testParseAssetEventIncorrectKindFails() throws {
    let sut = DefaultParser()
    let data = "FOOBAR 08/15/2020 Foo 12.345 1.2345 12.5"
    let transaction = try sut.assetEvent(fromData: Substring(data))
    XCTAssertNil(transaction)
  }

  func testParseTransactionIncorrectDateFormatFails() throws {
    let sut = DefaultParser()
    let data = "BUY abc Foo 12.345 1.2345 12.5"
    XCTAssertThrowsError(try sut.transaction(fromData: Substring(data)))
  }

  func testParseTransactionIncorrectNumberOfFieldsFails() throws {
    let sut = DefaultParser()
    let data = "BUY 15/08/2020 Foo 12.345 1.2345"
    XCTAssertThrowsError(try sut.transaction(fromData: Substring(data)))
  }

  func testParseTransactionIncorrectAmountFormatFails() throws {
    let sut = DefaultParser()
    let data = "BUY 15/08/2020 Foo abc 1.2345 12.5"
    XCTAssertThrowsError(try sut.transaction(fromData: Substring(data)))
  }

  func testParseTransactionIncorrectPriceFormatFails() throws {
    let sut = DefaultParser()
    let data = "BUY 15/08/2020 Foo 12.345 def 12.5"
    XCTAssertThrowsError(try sut.transaction(fromData: Substring(data)))
  }

  func testParseTransactionIncorrectExpensesFormatFails() throws {
    let sut = DefaultParser()
    let data = "BUY 15/08/2020 Foo 12.345 1.2345 abc"
    XCTAssertThrowsError(try sut.transaction(fromData: Substring(data)))
  }

  func testParseDividendAssetEventIncorrectDateFormatFails() throws {
    let sut = DefaultParser()
    let data = "DIVIDEND abc Foo 1.234 100"
    XCTAssertThrowsError(try sut.assetEvent(fromData: Substring(data)))
  }

  func testParseDividendAssetEventIncorrectNumberOfFieldsFails() throws {
    let sut = DefaultParser()
    let data = "DIVIDEND 15/08/2020 Foo 1.234 100 abc"
    XCTAssertThrowsError(try sut.assetEvent(fromData: Substring(data)))
  }

  func testParseDividendAssetEventIncorrectAmountFormatFails() throws {
    let sut = DefaultParser()
    let data = "DIVIDEND 15/08/2020 Foo abc 100"
    XCTAssertThrowsError(try sut.assetEvent(fromData: Substring(data)))
  }

  func testParseDividendAssetEventIncorrectValueFormatFails() throws {
    let sut = DefaultParser()
    let data = "DIVIDEND 15/08/2020 Foo 1.234 abc"
    XCTAssertThrowsError(try sut.assetEvent(fromData: Substring(data)))
  }

  func testParseCapitalReturnAssetEventIncorrectDateFormatFails() throws {
    let sut = DefaultParser()
    let data = "CAPRETURN abc Foo 1.234 100"
    XCTAssertThrowsError(try sut.assetEvent(fromData: Substring(data)))
  }

  func testParseCapitalReturnEventIncorrectNumberOfFieldsFails() throws {
    let sut = DefaultParser()
    let data = "CAPRETURN 15/08/2020 Foo 1.234 100 abc"
    XCTAssertThrowsError(try sut.assetEvent(fromData: Substring(data)))
  }

  func testParseCapitalReturnEventIncorrectAmountFormatFails() throws {
    let sut = DefaultParser()
    let data = "CAPRETURN 15/08/2020 Foo abc 100"
    XCTAssertThrowsError(try sut.assetEvent(fromData: Substring(data)))
  }

  func testParseCapitalReturnEventIncorrectValueFormatFails() throws {
    let sut = DefaultParser()
    let data = "CAPRETURN 15/08/2020 Foo 1.234 abc"
    XCTAssertThrowsError(try sut.assetEvent(fromData: Substring(data)))
  }

  func testParseSplitAssetEventIncorrectDateFormatFails() throws {
    let sut = DefaultParser()
    let data = "SPLIT abc Foo 10"
    XCTAssertThrowsError(try sut.assetEvent(fromData: Substring(data)))
  }

  func testParseSplitEventIncorrectNumberOfFieldsFails() throws {
    let sut = DefaultParser()
    let data = "SPLIT 15/08/2020 Foo 10 abc"
    XCTAssertThrowsError(try sut.assetEvent(fromData: Substring(data)))
  }

  func testParseSplitEventIncorrectAmountFormatFails() throws {
    let sut = DefaultParser()
    let data = "SPLIT 15/08/2020 Foo abc"
    XCTAssertThrowsError(try sut.assetEvent(fromData: Substring(data)))
  }

  func testParseUnsplitAssetEventIncorrectDateFormatFails() throws {
    let sut = DefaultParser()
    let data = "UNSPLIT abc Foo 10"
    XCTAssertThrowsError(try sut.assetEvent(fromData: Substring(data)))
  }

  func testParseUnsplitEventIncorrectNumberOfFieldsFails() throws {
    let sut = DefaultParser()
    let data = "UNSPLIT 15/08/2020 Foo 10 abc"
    XCTAssertThrowsError(try sut.assetEvent(fromData: Substring(data)))
  }

  func testParseUnsplitEventIncorrectAmountFormatFails() throws {
    let sut = DefaultParser()
    let data = "UNSPLIT 15/08/2020 Foo abc"
    XCTAssertThrowsError(try sut.assetEvent(fromData: Substring(data)))
  }

  func testEmptyDataCalculatorInput() throws {
    let sut = DefaultParser()
    let data = ""
    let calculatorInput = try sut.calculatorInput(fromData: data)
    XCTAssertEqual(calculatorInput.transactions.count, 0)
    XCTAssertEqual(calculatorInput.assetEvents.count, 0)
  }

  func testEmptyDataTransaction() throws {
    let sut = DefaultParser()
    let data = ""
    let transaction = try sut.transaction(fromData: Substring(data))
    XCTAssertNil(transaction)
  }

  func testEmptyDataAssetEvent() throws {
    let sut = DefaultParser()
    let data = ""
    let assetEvent = try sut.assetEvent(fromData: Substring(data))
    XCTAssertNil(assetEvent)
  }

  func testInvalidData() throws {
    let sut = DefaultParser()
    let data = "NOT A CORRECT ROW"
    XCTAssertThrowsError(try sut.calculatorInput(fromData: data))
  }
}
