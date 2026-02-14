//
//  TransactionTests.swift
//  CGTCalcCoreTests
//
//  Created by Matt Galloway on 19/06/2020.
//

@testable import CGTCalcCore
import XCTest

class TransactionTests: XCTestCase {
  func testGrouped() throws {
    let transactionA = ModelCreation.transaction(.Buy, "01/01/2020", "Foo", "10", "1", "5")
    let transactionB = ModelCreation.transaction(.Buy, "01/01/2020", "Foo", "20", "1.6", "10")
    let groupedTransaction = try Transaction.grouped([transactionA, transactionB])
    XCTAssertEqual(groupedTransaction.amount, Decimal(string: "30"))
    XCTAssertEqual(groupedTransaction.price, Decimal(string: "1.4"))
    XCTAssertEqual(groupedTransaction.expenses, Decimal(string: "15"))
  }

  func testGroupedMultiple() throws {
    let transactionA = ModelCreation.transaction(.Buy, "01/01/2020", "Foo", "10", "1", "5")
    let transactionB = ModelCreation.transaction(.Buy, "01/01/2020", "Foo", "20", "1.6", "10")
    let transactionC = ModelCreation.transaction(.Buy, "01/01/2020", "Foo", "30", "1.8", "100")
    let groupedTransaction = try Transaction.grouped([transactionA, transactionB, transactionC])
    XCTAssertEqual(groupedTransaction.amount, Decimal(string: "60"))
    XCTAssertEqual(groupedTransaction.price, Decimal(string: "1.6"))
    XCTAssertEqual(groupedTransaction.expenses, Decimal(string: "115"))
  }

  func testGroupedDifferentKind() throws {
    let transactionA = ModelCreation.transaction(.Buy, "01/01/2020", "Foo", "10", "1", "5")
    let transactionB = ModelCreation.transaction(.Sell, "01/01/2020", "Foo", "20", "1.6", "10")
    XCTAssertThrowsError(try Transaction.grouped([transactionA, transactionB]))
  }

  func testGroupedDifferentDate() throws {
    let transactionA = ModelCreation.transaction(.Buy, "01/01/2020", "Foo", "10", "1", "5")
    let transactionB = ModelCreation.transaction(.Buy, "02/01/2020", "Foo", "20", "1.6", "10")
    XCTAssertThrowsError(try Transaction.grouped([transactionA, transactionB]))
  }

  func testGroupedDifferentAsset() throws {
    let transactionA = ModelCreation.transaction(.Buy, "01/01/2020", "Foo", "10", "1", "5")
    let transactionB = ModelCreation.transaction(.Buy, "01/01/2020", "Bar", "20", "1.6", "10")
    XCTAssertThrowsError(try Transaction.grouped([transactionA, transactionB]))
  }

  func testGroupedEmptyArray() throws {
    XCTAssertThrowsError(try Transaction.grouped([]))
  }

  func testEquality() {
    let a = ModelCreation.transaction(.Buy, "01/01/2020", "Foo", "10", "1", "5")
    let b = ModelCreation.transaction(.Buy, "01/01/2020", "Foo", "10", "1", "5")
    let c = a
    XCTAssertNotEqual(a, b)
    XCTAssertNotEqual(b, c)
    XCTAssertEqual(a, c)
  }

  func testHashable() {
    let a = ModelCreation.transaction(.Buy, "01/01/2020", "Foo", "10", "1", "5")
    let b = ModelCreation.transaction(.Buy, "01/01/2020", "Foo", "10", "1", "5")
    let c = a
    let set = Set<Transaction>([a, b, c])
    XCTAssertEqual(set.count, 2)
    XCTAssertTrue(set.contains(a))
    XCTAssertTrue(set.contains(b))
  }
}
