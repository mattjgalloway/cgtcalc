//
//  MatchingProcessorTests.swift
//  CGTCalcCoreTests
//
//  Created by Matt Galloway on 10/06/2020.
//

import XCTest
@testable import CGTCalcCore

class MatchingProcessorTests: XCTestCase {

  let logger = StubLogger()

  func testSimple() throws {
    let acquisition1 = ModelCreation.transaction(.Buy, "01/01/2020", "Foo", "1000", "1", "0")
    let acquisition2 = ModelCreation.transaction(.Buy, "01/02/2020", "Foo", "1000", "1", "0")
    let acquisition3 = ModelCreation.transaction(.Buy, "10/03/2020", "Foo", "1000", "1", "0")
    let acquisition4 = ModelCreation.transaction(.Buy, "10/04/2020", "Foo", "500", "1", "0")
    let acquisition1Sub = TransactionToMatch(transaction: acquisition1)
    let acquisition2Sub = TransactionToMatch(transaction: acquisition2)
    let acquisition3Sub = TransactionToMatch(transaction: acquisition3)
    let acquisition4Sub = TransactionToMatch(transaction: acquisition4)

    let disposal1 = ModelCreation.transaction(.Sell, "01/02/2020", "Foo", "1000", "1", "0")
    let disposal2 = ModelCreation.transaction(.Sell, "01/03/2020", "Foo", "500", "1", "0")
    let disposal3 = ModelCreation.transaction(.Sell, "01/04/2020", "Foo", "1000", "1", "0")
    let disposal1Sub = TransactionToMatch(transaction: disposal1)
    let disposal2Sub = TransactionToMatch(transaction: disposal2)
    let disposal3Sub = TransactionToMatch(transaction: disposal3)

    let state = AssetProcessorState(
      asset: "Foo",
      acquisitions: [acquisition1Sub, acquisition2Sub, acquisition3Sub, acquisition4Sub],
      disposals: [disposal1Sub, disposal2Sub, disposal3Sub],
      assetEvents: [])

    let sut = MatchingProcessor(state: state, logger: self.logger)
    try sut.process()

    // Matched all but the first one
    XCTAssertEqual(state.matchedAcquisitions.count, 3)

    // Processed 3 disposals (but one was split, see below)
    XCTAssertEqual(state.processedDisposals.count, 3)

    // There's all of acquisition1 and the split of acquisition3 left
    XCTAssertEqual(state.pendingAcquisitions.count, 2)

    // There's the split of disposal3 left
    XCTAssertEqual(state.pendingDisposals.count, 1)

    // Processed 3 disposals so 3 matches
    XCTAssertEqual(state.disposalMatches.count, 3)
  }

}
