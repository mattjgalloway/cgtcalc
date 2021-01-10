//
//  MatchingProcessorTests.swift
//  CGTCalcCoreTests
//
//  Created by Matt Galloway on 10/06/2020.
//

@testable import CGTCalcCore
import XCTest

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

  func testWithAssetEvents() throws {
    let acquisition1 = ModelCreation.transaction(.Buy, "01/01/2020", "Foo", "1000", "2", "10")
    let acquisition2 = ModelCreation.transaction(.Buy, "20/01/2020", "Foo", "2000", "1.7", "15")
    let acquisition1Sub = TransactionToMatch(transaction: acquisition1)
    let acquisition2Sub = TransactionToMatch(transaction: acquisition2)

    let disposal1 = ModelCreation.transaction(.Sell, "10/01/2020", "Foo", "1000", "2.5", "2")
    let disposal1Sub = TransactionToMatch(transaction: disposal1)

    let state = AssetProcessorState(
      asset: "Foo",
      acquisitions: [acquisition1Sub, acquisition2Sub],
      disposals: [disposal1Sub],
      assetEvents: [
        ModelCreation.assetEvent(.CapitalReturn(1000, 0.1), "02/01/2020", "Foo"),
        ModelCreation.assetEvent(.Dividend(1000, 0.4), "02/01/2020", "Foo"),
        ModelCreation.assetEvent(.Split(4), "15/01/2020", "Foo"),
        ModelCreation.assetEvent(.Unsplit(2), "16/01/2020", "Foo")
      ])

    let sut = MatchingProcessor(state: state, logger: self.logger)
    try sut.process()

    XCTAssertEqual(state.matchedAcquisitions.count, 1)
    XCTAssertEqual(state.processedDisposals.count, 1)
    XCTAssertEqual(state.pendingAcquisitions.count, 1)
    XCTAssertEqual(state.pendingDisposals.count, 0)
    XCTAssertEqual(state.disposalMatches.count, 1)

    if let disposalMatch1 = state.disposalMatches.first {
      // Should match the disposal against the acquisition 10 days later under B&B rules
      let isBandB = { () -> Bool in
        if case DisposalMatch.Kind.BedAndBreakfast = disposalMatch1.kind { return true } else { return false }
      }()
      XCTAssertTrue(isBandB)
      XCTAssertEqual(disposalMatch1.gain, -917)
    }
  }
}
