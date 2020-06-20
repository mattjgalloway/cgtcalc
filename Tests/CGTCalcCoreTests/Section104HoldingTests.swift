//
//  Section104HoldingTests.swift
//  CGTCalcCoreTests
//
//  Created by Matt Galloway on 09/06/2020.
//

import XCTest
@testable import CGTCalcCore

class Section104HoldingTests: XCTestCase {

  func testProcessesAcquisitionsCorrectly() throws {
    let sut = Section104Holding(logger: StubLogger())

    do {
      let acquisition = ModelCreation.transaction(.Buy, "15/08/2020", "Foo", "100", "1", "10")
      sut.process(acquisition: TransactionToMatch(transaction: acquisition))
      XCTAssertEqual(sut.state.amount, Decimal(string: "100"))
      XCTAssertEqual(sut.state.cost, Decimal(string: "110"))
      XCTAssertEqual(sut.state.costBasis, Decimal(string: "1.1"))
    }

    do {
      let acquisition = ModelCreation.transaction(.Buy, "16/08/2020", "Foo", "100", "1.1", "20")
      sut.process(acquisition: TransactionToMatch(transaction: acquisition))
      XCTAssertEqual(sut.state.amount, Decimal(string: "200"))
      XCTAssertEqual(sut.state.cost, Decimal(string: "240"))
      XCTAssertEqual(sut.state.costBasis, Decimal(string: "1.2"))
    }
  }

  func testProcessesDisposalsCorrectly() throws {
    let sut = Section104Holding(logger: StubLogger())

    do {
      let acquisition = ModelCreation.transaction(.Buy, "15/08/2020", "Foo", "100", "1", "10")
      sut.process(acquisition: TransactionToMatch(transaction: acquisition))
      XCTAssertEqual(sut.state.amount, Decimal(string: "100"))
      XCTAssertEqual(sut.state.cost, Decimal(string: "110"))
      XCTAssertEqual(sut.state.costBasis, Decimal(string: "1.1"))
    }

    do {
      let disposal = ModelCreation.transaction(.Sell, "16/08/2020", "Foo", "35", "1.1", "20")
      _ = try sut.process(disposal: TransactionToMatch(transaction: disposal))
      XCTAssertEqual(sut.state.amount, Decimal(string: "65"))
      XCTAssertEqual(sut.state.cost, Decimal(string: "71.5"))
      XCTAssertEqual(sut.state.costBasis, Decimal(string: "1.1"))
    }
  }

  func testProcessesManyDisposalsCorrectly() throws {
    let sut = Section104Holding(logger: StubLogger())

    do {
      let acquisition = ModelCreation.transaction(.Buy, "15/08/2020", "Foo", "100", "1", "10")
      sut.process(acquisition: TransactionToMatch(transaction: acquisition))
      XCTAssertEqual(sut.state.amount, Decimal(string: "100"))
      XCTAssertEqual(sut.state.cost, Decimal(string: "110"))
      XCTAssertEqual(sut.state.costBasis, Decimal(string: "1.1"))
    }

    do {
      let disposal = ModelCreation.transaction(.Sell, "16/08/2020", "Foo", "35", "1.1", "20")
      let disposalMatch = try sut.process(disposal: TransactionToMatch(transaction: disposal))
      XCTAssertEqual(sut.state.amount, Decimal(string: "65"))
      XCTAssertEqual(sut.state.cost, Decimal(string: "71.5"))
      XCTAssertEqual(sut.state.costBasis, Decimal(string: "1.1"))
      XCTAssertEqual(disposalMatch.gain, Decimal(string: "-20"))
    }

    do {
      let acquisition = ModelCreation.transaction(.Buy, "17/08/2020", "Foo", "100", "1.76", "0")
      sut.process(acquisition: TransactionToMatch(transaction: acquisition))
      XCTAssertEqual(sut.state.amount, Decimal(string: "165"))
      XCTAssertEqual(sut.state.cost, Decimal(string: "247.5"))
      XCTAssertEqual(sut.state.costBasis, Decimal(string: "1.5"))
    }

    do {
      let disposal = ModelCreation.transaction(.Sell, "18/08/2020", "Foo", "35", "1.1", "0")
      let disposalMatch = try sut.process(disposal: TransactionToMatch(transaction: disposal))
      XCTAssertEqual(sut.state.amount, Decimal(string: "130"))
      XCTAssertEqual(sut.state.cost, Decimal(string: "195"))
      XCTAssertEqual(sut.state.costBasis, Decimal(string: "1.5"))
      XCTAssertEqual(disposalMatch.gain, Decimal(string: "-14"))
    }

    do {
      let disposal = ModelCreation.transaction(.Sell, "18/08/2020", "Foo", "130", "2.5", "0")
      let disposalMatch = try sut.process(disposal: TransactionToMatch(transaction: disposal))
      XCTAssertEqual(sut.state.amount, Decimal(string: "0"))
      XCTAssertEqual(sut.state.cost, Decimal(string: "0"))
      XCTAssertEqual(sut.state.costBasis, Decimal(string: "0"))
      XCTAssertEqual(disposalMatch.gain, Decimal(string: "130"))
    }
  }

  func testProcessesTooBigDisposalCorrectly() throws {
    let sut = Section104Holding(logger: StubLogger())

    let acquisition = ModelCreation.transaction(.Buy, "15/08/2020", "Foo", "100", "1", "10")
    sut.process(acquisition: TransactionToMatch(transaction: acquisition))
    XCTAssertEqual(sut.state.amount, Decimal(string: "100"))
    XCTAssertEqual(sut.state.cost, Decimal(string: "110"))
    XCTAssertEqual(sut.state.costBasis, Decimal(string: "1.1"))

    let disposal = ModelCreation.transaction(.Sell, "16/08/2020", "Foo", "200", "1", "10")
    XCTAssertThrowsError(try sut.process(disposal: TransactionToMatch(transaction: disposal)))
  }

  func testProcessesDisposalsWithSplitsCorrectly() throws {
    let sut = Section104Holding(logger: StubLogger())

    do {
      let acquisition = ModelCreation.transaction(.Buy, "01/01/2020", "Foo", "100", "1", "0")
      sut.process(acquisition: TransactionToMatch(transaction: acquisition))
      XCTAssertEqual(sut.state.amount, Decimal(string: "100"))
      XCTAssertEqual(sut.state.cost, Decimal(string: "100"))
      XCTAssertEqual(sut.state.costBasis, Decimal(string: "1"))
    }

    do {
      let split = ModelCreation.assetEvent(.Split(Decimal(2)), "01/02/2020", "Foo")
      sut.process(assetEvent: split)
      XCTAssertEqual(sut.state.amount, Decimal(string: "200"))
      XCTAssertEqual(sut.state.cost, Decimal(string: "100"))
      XCTAssertEqual(sut.state.costBasis, Decimal(string: "0.5"))
    }

    do {
      let disposal = ModelCreation.transaction(.Sell, "01/03/2020", "Foo", "50", "1", "0")
      _ = try sut.process(disposal: TransactionToMatch(transaction: disposal))
      XCTAssertEqual(sut.state.amount, Decimal(string: "150"))
      XCTAssertEqual(sut.state.cost, Decimal(string: "75"))
      XCTAssertEqual(sut.state.costBasis, Decimal(string: "0.5"))
    }

    do {
      let split = ModelCreation.assetEvent(.Split(Decimal(10)), "01/04/2020", "Foo")
      sut.process(assetEvent: split)
      XCTAssertEqual(sut.state.amount, Decimal(string: "1500"))
      XCTAssertEqual(sut.state.cost, Decimal(string: "75"))
      XCTAssertEqual(sut.state.costBasis, Decimal(string: "0.05"))
    }

    do {
      let disposal = ModelCreation.transaction(.Sell, "01/05/2020", "Foo", "500", "1", "0")
      _ = try sut.process(disposal: TransactionToMatch(transaction: disposal))
      XCTAssertEqual(sut.state.amount, Decimal(string: "1000"))
      XCTAssertEqual(sut.state.cost, Decimal(string: "50"))
      XCTAssertEqual(sut.state.costBasis, Decimal(string: "0.05"))
    }

    do {
      let unsplit = ModelCreation.assetEvent(.Unsplit(Decimal(20)), "01/06/2020", "Foo")
      sut.process(assetEvent: unsplit)
      XCTAssertEqual(sut.state.amount, Decimal(string: "50"))
      XCTAssertEqual(sut.state.cost, Decimal(string: "50"))
      XCTAssertEqual(sut.state.costBasis, Decimal(string: "1"))
    }

    do {
      let disposal = ModelCreation.transaction(.Sell, "01/07/2020", "Foo", "50", "1", "0")
      _ = try sut.process(disposal: TransactionToMatch(transaction: disposal))
      XCTAssertEqual(sut.state.amount, Decimal(string: "0"))
      XCTAssertEqual(sut.state.cost, Decimal(string: "0"))
      XCTAssertEqual(sut.state.costBasis, Decimal(string: "0"))
    }
  }

}
