//
//  DisposalMatchTests.swift
//  CGTCalcCoreTests
//
//  Created by Matt Galloway on 09/06/2020.
//

import XCTest
@testable import CGTCalcCore

class DisposalMatchTests: XCTestCase {

  func testMatchingDisposal() throws {
    let acquisition = ModelCreation.transaction(.Buy, "15/08/2020", "Foo", "100", "2", "10")
    let disposal = ModelCreation.transaction(.Sell, "16/08/2020", "Foo", "100", "3", "20")

    let disposalMatch = DisposalMatch(kind: .SameDay(TransactionToMatch(transaction: acquisition)), disposal: TransactionToMatch(transaction: disposal))

    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
    dateFormatter.dateFormat = "dd/MM/yyyy"

    XCTAssertEqual(disposalMatch.asset, "Foo")
    XCTAssertEqual(disposalMatch.date, Date(timeIntervalSince1970: 1597536000))
    XCTAssertEqual(disposalMatch.taxYear, TaxYear(year: 2021))
    XCTAssertEqual(disposalMatch.gain, Decimal(string: "70"))
  }

  func testSection104Disposal() throws {
    let disposal = ModelCreation.transaction(.Sell, "16/08/2020", "Foo", "100", "3", "20")

    let disposalMatch = DisposalMatch(kind: .Section104(Decimal(string: "100")!, Decimal(string: "2.5")!), disposal: TransactionToMatch(transaction: disposal))

    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
    dateFormatter.dateFormat = "dd/MM/yyyy"

    XCTAssertEqual(disposalMatch.asset, "Foo")
    XCTAssertEqual(disposalMatch.date, Date(timeIntervalSince1970: 1597536000))
    XCTAssertEqual(disposalMatch.taxYear, TaxYear(year: 2021))
    XCTAssertEqual(disposalMatch.gain, Decimal(string: "30"))
  }

}
