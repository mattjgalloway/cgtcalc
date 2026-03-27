@testable import CGTCalcCore
import XCTest

final class Section104ProcessorTests: XCTestCase {
  func testActionsSortBuysBeforeEventsOnSameDate() {
    let buy = TestSupport.buy("01/03/2019", "TEST", 100, 10, 0, sourceOrder: 1)
    let event = TestSupport.capReturn("01/03/2019", "TEST", 100, 50, sourceOrder: 0)

    let actions = Section104Processor.actions(
      buys: [buy],
      events: [event],
      after: Date.distantPast,
      through: TestSupport.date("01/03/2019"))

    XCTAssertEqual(actions.count, 2)
    guard case .buy = actions[0] else { return XCTFail("Expected buy first") }
    guard case .event = actions[1] else { return XCTFail("Expected event second") }
  }

  func testActionsUseSourceOrderForSameDateSameTypeRows() {
    let buy1 = TestSupport.buy("01/03/2019", "TEST", 100, 10, 0, sourceOrder: 2)
    let buy2 = TestSupport.buy("01/03/2019", "TEST", 100, 12, 0, sourceOrder: 1)
    let event1 = TestSupport.capReturn("01/03/2019", "TEST", 100, 50, sourceOrder: 4)
    let event2 = TestSupport.dividend("01/03/2019", "TEST", 100, 25, sourceOrder: 3)

    let actions = Section104Processor.actions(
      buys: [buy1, buy2],
      events: [event1, event2],
      after: Date.distantPast,
      through: TestSupport.date("01/03/2019"))

    XCTAssertEqual(actions.count, 4)

    guard case .buy(let firstBuy) = actions[0] else { return XCTFail("Expected buy first") }
    guard case .buy(let secondBuy) = actions[1] else { return XCTFail("Expected buy second") }
    guard case .event(let firstEvent) = actions[2] else { return XCTFail("Expected event third") }
    guard case .event(let secondEvent) = actions[3] else { return XCTFail("Expected event fourth") }

    XCTAssertEqual(firstBuy.sourceOrder, 1)
    XCTAssertEqual(secondBuy.sourceOrder, 2)
    XCTAssertEqual(firstEvent.sourceOrder, 3)
    XCTAssertEqual(secondEvent.sourceOrder, 4)
  }

  func testProcessActionsBuildsHoldingAndAppliesCapitalReturn() {
    let buy = TestSupport.buy("01/01/2019", "TEST", 100, 10, 0)
    let event = TestSupport.capReturn("01/03/2019", "TEST", 100, 50)
    let actions = Section104Processor.actions(
      buys: [buy],
      events: [event],
      after: Date.distantPast,
      through: TestSupport.date("01/03/2019"))

    let holding = Section104Processor.processActions(
      actions,
      into: Section104Holding(),
      usedBuyQuantities: [:])

    XCTAssertEqual(holding.quantity, 100)
    XCTAssertEqual(holding.costBasis, 950)
    XCTAssertEqual(holding.pool.count, 1)
  }

  func testProcessActionsDoesNotUseSameDayBuyToPriceDisposalButKeepsRemainder() {
    let buy = TestSupport.buy("01/06/2019", "TEST", 100, 10, 0)
    let actions = Section104Processor.actions(
      buys: [buy],
      events: [],
      after: Date.distantPast,
      through: TestSupport.date("01/06/2019"))

    let holding = Section104Processor.processActions(
      actions,
      into: Section104Holding(),
      usedBuyQuantities: [buy.id: 40])

    XCTAssertEqual(holding.quantity, 60)
    XCTAssertEqual(holding.costBasis, 600, accuracy: 0.00001)
  }

  func testProcessActionsAddsUnmatchedRemainderOfSameDayBuyAfterDisposal() {
    let buy = TestSupport.buy("01/06/2019", "TEST", 100, 10, 0)
    let actions = Section104Processor.actions(
      buys: [buy],
      events: [],
      after: Date.distantPast,
      through: TestSupport.date("01/06/2019"))

    let holding = Section104Processor.processActions(
      actions,
      into: Section104Holding(),
      usedBuyQuantities: [buy.id: 40])

    XCTAssertEqual(holding.quantity, 60)
    XCTAssertEqual(holding.costBasis, 600, accuracy: 0.00001)
    XCTAssertEqual(holding.pool.count, 1)
    XCTAssertEqual(holding.pool[0].quantity, 60)
  }

  func testMakeMatchesUsesPoolAverageCost() {
    let buy1 = TestSupport.buy("01/01/2019", "TEST", 100, 10, 0, sourceOrder: 0)
    let buy2 = TestSupport.buy("01/02/2019", "TEST", 100, 12, 0, sourceOrder: 1)
    let holding = Section104Processor.processActions(
      Section104Processor.actions(
        buys: [buy1, buy2],
        events: [],
        after: Date.distantPast,
        through: TestSupport.date("01/02/2019")),
      into: Section104Holding(),
      usedBuyQuantities: [:])

    let matches = Section104Processor.makeMatches(quantityNeeded: 50, holding: holding)

    XCTAssertEqual(matches.count, 1)
    XCTAssertEqual(matches[0].quantity, 50)
    XCTAssertEqual(matches[0].cost, 550, accuracy: 0.00001)
  }

  func testApplyMatchesReducesHoldingQuantityCostAndPool() {
    let buy1 = TestSupport.buy("01/01/2019", "TEST", 100, 10, 0, sourceOrder: 0)
    let buy2 = TestSupport.buy("01/02/2019", "TEST", 100, 12, 0, sourceOrder: 1)
    let holding = Section104Processor.processActions(
      Section104Processor.actions(
        buys: [buy1, buy2],
        events: [],
        after: Date.distantPast,
        through: TestSupport.date("01/02/2019")),
      into: Section104Holding(),
      usedBuyQuantities: [:])

    let matches = Section104Processor.makeMatches(quantityNeeded: 150, holding: holding)
    let updatedHolding = Section104Processor.applyMatches(matches, to: holding)

    XCTAssertEqual(updatedHolding.quantity, 50)
    XCTAssertEqual(updatedHolding.costBasis, 550, accuracy: 0.00001)
    XCTAssertEqual(updatedHolding.pool[0].quantity, 0)
    XCTAssertEqual(updatedHolding.pool[1].quantity, 50)
  }

  func testMakeMatchesUsesSourceOrderForSameDateBuys() {
    let buy1 = TestSupport.buy("01/01/2019", "TEST", 100, 10, 0, sourceOrder: 1)
    let buy2 = TestSupport.buy("01/01/2019", "TEST", 100, 12, 0, sourceOrder: 0)
    let holding = Section104Processor.processActions(
      Section104Processor.actions(
        buys: [buy1, buy2],
        events: [],
        after: Date.distantPast,
        through: TestSupport.date("01/01/2019")),
      into: Section104Holding(),
      usedBuyQuantities: [:])

    let matches = Section104Processor.makeMatches(quantityNeeded: 150, holding: holding)

    XCTAssertEqual(matches.count, 2)
    XCTAssertEqual(matches[0].sourceOrder, 0)
    XCTAssertEqual(matches[0].quantity, 100)
    XCTAssertEqual(matches[1].sourceOrder, 1)
    XCTAssertEqual(matches[1].quantity, 50)
  }

  func testProcessActionsAddsOnlyUnmatchedRemainderOfPartlyUsedBuy() {
    let buy = TestSupport.buy("15/08/2016", "NASDAQ:META", 107, 96.28, 0)
    let actions = Section104Processor.actions(
      buys: [buy],
      events: [],
      after: Date.distantPast,
      through: nil)

    let holding = Section104Processor.processActions(
      actions,
      into: Section104Holding(),
      usedBuyQuantities: [buy.id: 106])

    XCTAssertEqual(holding.quantity, 1)
    XCTAssertEqual(holding.costBasis, 96.28, accuracy: 0.00001)
    XCTAssertEqual(holding.pool.count, 1)
    XCTAssertEqual(holding.pool[0].quantity, 1)
  }

  func testApplyRestructureEventsIgnoresNonRestructureEventTypes() {
    let initialHolding = Section104Holding(
      quantity: 100,
      costBasis: 500,
      pool: [
        Section104Match(
          transactionId: UUID(),
          quantity: 100,
          cost: 500,
          date: TestSupport.date("01/01/2019"),
          poolQuantity: 100,
          poolCost: 500)
      ])
    let events = [
      TestSupport.capReturn("02/01/2019", "TEST", 100, 10),
      TestSupport.dividend("03/01/2019", "TEST", 100, 20)
    ]

    let updated = Section104Processor.applyRestructureEvents(events, to: initialHolding)

    XCTAssertEqual(updated.quantity, 100)
    XCTAssertEqual(updated.costBasis, 500)
    XCTAssertEqual(updated.pool.count, 1)
    XCTAssertEqual(updated.pool[0].quantity, 100)
    XCTAssertEqual(updated.pool[0].poolQuantity, 100)
  }

  func testApplyRestructureEventsSupportsExactRatioRestruct() {
    let initialHolding = Section104Holding(
      quantity: 30,
      costBasis: 300,
      pool: [
        Section104Match(
          transactionId: UUID(),
          quantity: 30,
          cost: 300,
          date: TestSupport.date("01/01/2019"),
          poolQuantity: 30,
          poolCost: 300)
      ])
    let restruct = AssetEvent(
      date: TestSupport.date("02/01/2019"),
      asset: "TEST",
      oldUnits: 3,
      newUnits: 7)

    let updated = Section104Processor.applyRestructureEvents([restruct], to: initialHolding)

    XCTAssertEqual(updated.quantity, 70, accuracy: 0.00001)
    XCTAssertEqual(updated.costBasis, 300, accuracy: 0.00001)
    XCTAssertEqual(updated.pool[0].quantity, 70, accuracy: 0.00001)
    XCTAssertEqual(updated.pool[0].poolQuantity, 70, accuracy: 0.00001)
  }

  func testActionsUseUUIDTieBreakForSameDateEventsWithoutSourceOrder() throws {
    let sameDate = TestSupport.date("01/03/2019")
    let eventA = try AssetEvent(
      type: .capitalReturn,
      date: sameDate,
      asset: "TEST",
      distributionAmount: 100,
      distributionValue: 10)
    let eventB = try AssetEvent(
      type: .dividend,
      date: sameDate,
      asset: "TEST",
      distributionAmount: 100,
      distributionValue: 20)

    let actions = Section104Processor.actions(
      buys: [],
      events: [eventA, eventB],
      after: Date.distantPast,
      through: sameDate)

    XCTAssertEqual(actions.count, 2)

    let expectedFirstID = min(eventA.id.uuidString, eventB.id.uuidString)
    guard case .event(let firstEvent) = actions[0] else { return XCTFail("Expected event first") }
    XCTAssertEqual(firstEvent.id.uuidString, expectedFirstID)
  }
}
