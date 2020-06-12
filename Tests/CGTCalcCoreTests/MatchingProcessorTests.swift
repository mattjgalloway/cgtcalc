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
    let acquisition1 = ModelCreation.transaction(1, .Buy, "01/01/2020", "Foo", "1000", "1", "0")
    let acquisition2 = ModelCreation.transaction(2, .Buy, "02/01/2020", "Foo", "1000", "1", "0")
    let acquisition3 = ModelCreation.transaction(3, .Buy, "03/01/2020", "Foo", "1000", "1", "0")
    let acquisition4 = ModelCreation.transaction(4, .Buy, "04/01/2020", "Foo", "500", "1", "0")
    let acquisition1Sub = SubTransaction(transaction: acquisition1)
    let acquisition2Sub = SubTransaction(transaction: acquisition2)
    let acquisition3Sub = SubTransaction(transaction: acquisition3)
    let acquisition4Sub = SubTransaction(transaction: acquisition4)

    let disposal1 = ModelCreation.transaction(5, .Sell, "01/01/2020", "Foo", "1000", "1", "0")
    let disposal2 = ModelCreation.transaction(6, .Sell, "02/01/2020", "Foo", "1000", "1", "0")
    let disposal3 = ModelCreation.transaction(7, .Sell, "03/01/2020", "Foo", "500", "1", "0")
    let disposal4 = ModelCreation.transaction(8, .Sell, "04/01/2020", "Foo", "1000", "1", "0")
    let disposal1Sub = SubTransaction(transaction: disposal1)
    let disposal2Sub = SubTransaction(transaction: disposal2)
    let disposal3Sub = SubTransaction(transaction: disposal3)
    let disposal4Sub = SubTransaction(transaction: disposal4)

    let state = AssetProcessorState(
      asset: "Foo",
      acquisitions: [acquisition1Sub, acquisition2Sub, acquisition3Sub, acquisition4Sub],
      disposals: [disposal1Sub, disposal2Sub, disposal3Sub, disposal4Sub],
      assetEvents: [])

    let sut = MatchingProcessor(state: state, logger: self.logger) { (acquisition, disposal) in
      if acquisition === acquisition1Sub {
        return .SkipAcquisition
      }
      if disposal === disposal1Sub {
        return .SkipDisposal
      }
      if acquisition === acquisition2Sub && disposal === disposal2Sub {
        let match = DisposalMatch(kind: .SameDay(acquisition), disposal: disposal)
        return .Match(match)
      }
      if acquisition === acquisition3Sub && disposal === disposal3Sub {
        let match = DisposalMatch(kind: .SameDay(acquisition), disposal: disposal)
        return .Match(match)
      }
      if acquisition === acquisition4Sub && disposal === disposal4Sub {
        let match = DisposalMatch(kind: .SameDay(acquisition), disposal: disposal)
        return .Match(match)
      }
      if acquisition.date < disposal.date {
        return .SkipAcquisition
      }
      return .SkipDisposal
    }
    try sut.process()

    // 1 was skipped
    XCTAssertEqual(state.matchedAcquisitions.count, 3)
    XCTAssertEqual(state.processedDisposals.count, 3)

    // 1 was skipped, 1 was split
    XCTAssertEqual(state.pendingAcquisitions.count, 2)
    XCTAssertEqual(state.pendingDisposals.count, 2)

    XCTAssertEqual(state.disposalMatches.count, 3)
  }

}
