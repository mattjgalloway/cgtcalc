@testable import CGTCalcCore
import XCTest

final class Section104ProcessorTests: XCTestCase {
  private let tolerance = QuantityMaths.arithmeticDustTolerance

  func testSellingEntireRepeatingAveragePoolConsumesExactCost() throws {
    let buys = [
      TestSupport.buy("01/01/2020", "TEST", 1, 10, 0),
      TestSupport.buy("02/01/2020", "TEST", 2, 45, 0)
    ]
    let holding = try Section104Processor.processActions(
      Section104Processor.actions(buys: buys, events: [], after: .distantPast, through: nil),
      into: Section104Holding(),
      usedBuyQuantities: [:])

    let matches = Section104Processor.makeMatches(quantityNeeded: 3, holding: holding)
    let remaining = Section104Processor.applyMatches(matches, to: holding)

    XCTAssertEqual(matches.reduce(Decimal(0)) { $0 + $1.cost }, 100)
    XCTAssertEqual(remaining.costBasis, 0)
  }

  func testMakeMatchesReconcilesDifferenceExactlyAtTolerance() throws {
    let holding = try self.makeHolding(quantity: 10, price: 10)
    let matches = Section104Processor.makeMatches(
      quantityNeeded: 10 + self.tolerance,
      holding: holding)

    XCTAssertEqual(matches.reduce(0) { $0 + $1.quantity }, 10 + self.tolerance)
    XCTAssertEqual(matches.reduce(0) { $0 + $1.cost }, holding.costBasis)
  }

  func testMakeMatchesDoesNotReconcileDifferenceBeyondTolerance() throws {
    let beyondTolerance = try XCTUnwrap(Decimal.parse("0.0000000100000001"))
    let holding = try self.makeHolding(quantity: 10, price: 10)
    let matches = Section104Processor.makeMatches(
      quantityNeeded: 10 + beyondTolerance,
      holding: holding)

    XCTAssertEqual(matches.reduce(0) { $0 + $1.quantity }, 10)
  }

  func testMakeMatchesReconcilesPoolSlightlyBelowRequestedQuantity() throws {
    let available = 10 - self.tolerance
    let holding = try self.makeHolding(quantity: available, price: 10)
    let matches = Section104Processor.makeMatches(quantityNeeded: 10, holding: holding)
    let remaining = Section104Processor.applyMatches(matches, to: holding)

    XCTAssertEqual(matches.reduce(0) { $0 + $1.quantity }, 10)
    XCTAssertEqual(matches.reduce(0) { $0 + $1.cost }, holding.costBasis)
    XCTAssertEqual(remaining.quantity, 0)
    XCTAssertEqual(remaining.costBasis, 0)
    XCTAssertTrue(remaining.pool.isEmpty)
  }

  func testMakeMatchesReconcilesPoolSlightlyAboveRequestedQuantity() throws {
    let available = 10 + self.tolerance
    let holding = try self.makeHolding(quantity: available, price: 10)
    let matches = Section104Processor.makeMatches(quantityNeeded: 10, holding: holding)
    let remaining = Section104Processor.applyMatches(matches, to: holding)

    XCTAssertEqual(matches.reduce(0) { $0 + $1.quantity }, 10)
    XCTAssertEqual(matches.reduce(0) { $0 + $1.cost }, holding.costBasis)
    XCTAssertEqual(remaining.quantity, 0)
    XCTAssertEqual(remaining.costBasis, 0)
    XCTAssertTrue(remaining.pool.isEmpty)
  }

  func testMakeMatchesDoesNotMatchToleranceSizedRequestAgainstEmptyPool() {
    let matches = Section104Processor.makeMatches(
      quantityNeeded: self.tolerance,
      holding: Section104Holding())

    XCTAssertTrue(matches.isEmpty)
  }

  func testPartialDisposalDoesNotConsumeCompletePoolCostBasis() throws {
    let holding = try self.makeHolding(quantity: 10, price: 10)
    let matches = Section104Processor.makeMatches(quantityNeeded: 4, holding: holding)
    let remaining = Section104Processor.applyMatches(matches, to: holding)

    XCTAssertEqual(matches.reduce(0) { $0 + $1.cost }, 40)
    XCTAssertEqual(remaining.quantity, 6)
    XCTAssertEqual(remaining.costBasis, 60)
  }

  func testFullPoolReconciliationAdjustsOnlyFinalProvenanceLot() throws {
    let firstBuy = TestSupport.buy("01/01/2020", "TEST", 4, 10, 0, sourceOrder: 0)
    let secondBuy = TestSupport.buy("02/01/2020", "TEST", 6, 10, 0, sourceOrder: 1)
    let holding = try Section104Processor.processActions(
      Section104Processor.actions(
        buys: [firstBuy, secondBuy],
        events: [],
        after: .distantPast,
        through: nil),
      into: Section104Holding(),
      usedBuyQuantities: [:])
    let matches = Section104Processor.makeMatches(
      quantityNeeded: 10 + self.tolerance,
      holding: holding)
    let remaining = Section104Processor.applyMatches(matches, to: holding)

    XCTAssertEqual(matches.count, 2)
    XCTAssertEqual(matches[0].quantity, 4)
    XCTAssertEqual(matches[1].quantity, 6 + self.tolerance)
    XCTAssertEqual(matches.reduce(0) { $0 + $1.cost }, 100)
    XCTAssertEqual(remaining.quantity, 0)
    XCTAssertEqual(remaining.costBasis, 0)
    XCTAssertTrue(remaining.pool.isEmpty)
  }

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

  func testActionsUseCanonicalDistributionOrderBeforeSourceOrder() {
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
    XCTAssertEqual(firstEvent.distributionType, .dividend)
    XCTAssertEqual(secondEvent.distributionType, .capitalReturn)
  }

  func testProcessActionsBuildsHoldingAndAppliesCapitalReturn() throws {
    let buy = TestSupport.buy("01/01/2019", "TEST", 100, 10, 0)
    let event = TestSupport.capReturn("01/03/2019", "TEST", 100, 50)
    let actions = Section104Processor.actions(
      buys: [buy],
      events: [event],
      after: Date.distantPast,
      through: TestSupport.date("01/03/2019"))

    let holding = try Section104Processor.processActions(
      actions,
      into: Section104Holding(),
      usedBuyQuantities: [:])

    XCTAssertEqual(holding.quantity, 100)
    XCTAssertEqual(holding.costBasis, 950)
    XCTAssertEqual(holding.pool.count, 1)
  }

  func testProcessActionsDoesNotUseSameDayBuyToPriceDisposalButKeepsRemainder() throws {
    let buy = TestSupport.buy("01/06/2019", "TEST", 100, 10, 0)
    let actions = Section104Processor.actions(
      buys: [buy],
      events: [],
      after: Date.distantPast,
      through: TestSupport.date("01/06/2019"))

    let holding = try Section104Processor.processActions(
      actions,
      into: Section104Holding(),
      usedBuyQuantities: [buy.id: 40])

    XCTAssertEqual(holding.quantity, 60)
    XCTAssertEqual(holding.costBasis, 600, accuracy: 0.00001)
  }

  func testProcessActionsAddsUnmatchedRemainderOfSameDayBuyAfterDisposal() throws {
    let buy = TestSupport.buy("01/06/2019", "TEST", 100, 10, 0)
    let actions = Section104Processor.actions(
      buys: [buy],
      events: [],
      after: Date.distantPast,
      through: TestSupport.date("01/06/2019"))

    let holding = try Section104Processor.processActions(
      actions,
      into: Section104Holding(),
      usedBuyQuantities: [buy.id: 40])

    XCTAssertEqual(holding.quantity, 60)
    XCTAssertEqual(holding.costBasis, 600, accuracy: 0.00001)
    XCTAssertEqual(holding.pool.count, 1)
    XCTAssertEqual(holding.pool[0].quantity, 60)
  }

  func testMakeMatchesUsesPoolAverageCost() throws {
    let buy1 = TestSupport.buy("01/01/2019", "TEST", 100, 10, 0, sourceOrder: 0)
    let buy2 = TestSupport.buy("01/02/2019", "TEST", 100, 12, 0, sourceOrder: 1)
    let holding = try Section104Processor.processActions(
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

  func testApplyMatchesReducesHoldingQuantityCostAndPool() throws {
    let buy1 = TestSupport.buy("01/01/2019", "TEST", 100, 10, 0, sourceOrder: 0)
    let buy2 = TestSupport.buy("01/02/2019", "TEST", 100, 12, 0, sourceOrder: 1)
    let holding = try Section104Processor.processActions(
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

  func testMakeMatchesUsesSourceOrderForSameDateBuys() throws {
    let buy1 = TestSupport.buy("01/01/2019", "TEST", 100, 10, 0, sourceOrder: 1)
    let buy2 = TestSupport.buy("01/01/2019", "TEST", 100, 12, 0, sourceOrder: 0)
    let holding = try Section104Processor.processActions(
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

  func testProcessActionsAddsOnlyUnmatchedRemainderOfPartlyUsedBuy() throws {
    let buy = TestSupport.buy("15/08/2016", "NASDAQ:META", 107, 96.28, 0)
    let actions = Section104Processor.actions(
      buys: [buy],
      events: [],
      after: Date.distantPast,
      through: nil)

    let holding = try Section104Processor.processActions(
      actions,
      into: Section104Holding(),
      usedBuyQuantities: [buy.id: 106])

    XCTAssertEqual(holding.quantity, 1)
    XCTAssertEqual(holding.costBasis, 96.28, accuracy: 0.00001)
    XCTAssertEqual(holding.pool.count, 1)
    XCTAssertEqual(holding.pool[0].quantity, 1)
  }

  private func makeHolding(quantity: Decimal, price: Decimal) throws -> Section104Holding {
    let buy = TestSupport.buy("01/01/2020", "TEST", quantity, price, 0)
    return try Section104Processor.processActions(
      Section104Processor.actions(buys: [buy], events: [], after: .distantPast, through: nil),
      into: Section104Holding(),
      usedBuyQuantities: [:])
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
    let firstID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
    let secondID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000002"))
    let eventA = try AssetEvent(
      id: secondID,
      type: .dividend,
      date: sameDate,
      asset: "TEST",
      distributionAmount: 100,
      distributionValue: 10)
    let eventB = try AssetEvent(
      id: firstID,
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

    guard case .event(let firstEvent) = actions[0] else { return XCTFail("Expected event first") }
    XCTAssertEqual(firstEvent.id, firstID)
  }
}
