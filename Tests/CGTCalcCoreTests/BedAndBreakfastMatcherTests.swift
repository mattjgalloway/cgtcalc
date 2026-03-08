@testable import CGTCalcCore
import XCTest

final class BedAndBreakfastMatcherTests: XCTestCase {
  func testMatchesSameDayBuyFirst() {
    let sell = TestSupport.sell("01/06/2019", "TEST", 50, 12, 0)
    let sameDayBuy = TestSupport.buy("01/06/2019", "TEST", 50, 10, 0)

    let (matches, quantityUsed) = BedAndBreakfastMatcher.findMatches(
      for: sell,
      from: [sameDayBuy],
      usedBuyQuantities: [:],
      sortedEvents: [],
      allSells: [sell])

    XCTAssertEqual(matches.count, 1)
    XCTAssertEqual(quantityUsed, 50)
    XCTAssertEqual(matches[0].buyTransaction.id, sameDayBuy.id)
    XCTAssertEqual(matches[0].quantity, 50)
    XCTAssertEqual(matches[0].cost, 500)
  }

  func testMatchesBuyWithin30DayWindow() {
    let sell = TestSupport.sell("01/06/2019", "TEST", 50, 12, 0)
    let rebuy = TestSupport.buy("08/06/2019", "TEST", 50, 11, 0)

    let (matches, quantityUsed) = BedAndBreakfastMatcher.findMatches(
      for: sell,
      from: [rebuy],
      usedBuyQuantities: [:],
      sortedEvents: [],
      allSells: [sell])

    XCTAssertEqual(matches.count, 1)
    XCTAssertEqual(quantityUsed, 50)
    XCTAssertEqual(matches[0].buyTransaction.id, rebuy.id)
    XCTAssertEqual(matches[0].cost, 550)
  }

  func testDoesNotMatchBuyOutside30DayWindow() {
    let sell = TestSupport.sell("01/06/2019", "TEST", 50, 12, 0)
    let rebuy = TestSupport.buy("06/07/2019", "TEST", 50, 11, 0)

    let (matches, quantityUsed) = BedAndBreakfastMatcher.findMatches(
      for: sell,
      from: [rebuy],
      usedBuyQuantities: [:],
      sortedEvents: [],
      allSells: [sell])

    XCTAssertTrue(matches.isEmpty)
    XCTAssertEqual(quantityUsed, 0)
  }

  func testAdjustsRebuyQuantityAcrossSplit() {
    let sellDate = TestSupport.date("01/06/2019")
    let rebuy = TestSupport.buy("10/06/2019", "TEST", 200, 5, 0)
    let split = AssetEvent(type: .split, date: TestSupport.date("05/06/2019"), asset: "TEST", amount: 2, value: 0)

    let adjustedQuantity = BedAndBreakfastMatcher.adjustedQuantity(
      for: rebuy,
      relativeTo: sellDate,
      sortedEvents: [split])

    XCTAssertEqual(adjustedQuantity, 100)
  }

  func testIncludesPostBuyAssetEventOffsetsInMatchedCost() {
    let sell = TestSupport.sell("05/11/2019", "TEST", 20, 20, 0)
    let rebuy = TestSupport.buy("10/11/2019", "TEST", 20, 19, 2)
    let events = [
      TestSupport.dividend("30/11/2019", "TEST", 20, 110.93),
      TestSupport.capReturn("30/11/2019", "TEST", 20, 95.12)
    ]

    let (matches, quantityUsed) = BedAndBreakfastMatcher.findMatches(
      for: sell,
      from: [rebuy],
      usedBuyQuantities: [:],
      sortedEvents: events,
      allSells: [sell])

    XCTAssertEqual(matches.count, 1)
    XCTAssertEqual(quantityUsed, 20)
    XCTAssertEqual(matches[0].eventAdjustment, 15.81, accuracy: 0.00001)
    XCTAssertEqual(matches[0].cost, 397.81, accuracy: 0.00001)
  }

  func testUsesEventAmountWhenAllocatingPostBuyEventOffset() {
    let sell = TestSupport.sell("05/11/2019", "TEST", 20, 20, 0)
    let rebuy = TestSupport.buy("10/11/2019", "TEST", 20, 19, 2)
    let events = [
      TestSupport.dividend("30/11/2019", "TEST", 40, 100)
    ]

    let (matches, quantityUsed) = BedAndBreakfastMatcher.findMatches(
      for: sell,
      from: [rebuy],
      usedBuyQuantities: [:],
      sortedEvents: events,
      allSells: [sell])

    XCTAssertEqual(quantityUsed, 20)
    XCTAssertEqual(matches.count, 1)
    XCTAssertEqual(matches[0].eventAdjustment, 50, accuracy: 0.00001)
    XCTAssertEqual(matches[0].cost, 432, accuracy: 0.00001)
  }

  func testAllowsPartialReuseOfSingleRebuyAcrossMultipleEarlierSells() {
    let firstSell = TestSupport.sell("29/07/2016", "NASDAQ:META", 106, 94.71, 6.99)
    let secondSell = TestSupport.sell("10/08/2016", "NASDAQ:META", 1, 95.00, 0)
    let rebuy = TestSupport.buy("15/08/2016", "NASDAQ:META", 107, 96.28, 0)

    let (firstMatches, firstQuantityUsed) = BedAndBreakfastMatcher.findMatches(
      for: firstSell,
      from: [rebuy],
      usedBuyQuantities: [:],
      sortedEvents: [],
      allSells: [firstSell, secondSell])

    XCTAssertEqual(firstQuantityUsed, 106)
    XCTAssertEqual(firstMatches.count, 1)
    XCTAssertEqual(firstMatches[0].buyDateQuantity, 106)

    let (secondMatches, secondQuantityUsed) = BedAndBreakfastMatcher.findMatches(
      for: secondSell,
      from: [rebuy],
      usedBuyQuantities: [rebuy.id: firstMatches[0].buyDateQuantity],
      sortedEvents: [],
      allSells: [firstSell, secondSell])

    XCTAssertEqual(secondQuantityUsed, 1)
    XCTAssertEqual(secondMatches.count, 1)
    XCTAssertEqual(secondMatches[0].buyDateQuantity, 1)
  }

  func testAggregatesSameDayBuysForPartialMatchCosting() {
    let sell = TestSupport.sell("01/01/2020", "TEST", 10, 100, 0)
    let cheapBuy = TestSupport.buy("01/01/2020", "TEST", 10, 1, 100, sourceOrder: 0)
    let expensiveBuy = TestSupport.buy("01/01/2020", "TEST", 10, 100, 0, sourceOrder: 1)

    let (matches, quantityUsed) = BedAndBreakfastMatcher.findMatches(
      for: sell,
      from: [cheapBuy, expensiveBuy],
      usedBuyQuantities: [:],
      sortedEvents: [],
      allSells: [sell])

    XCTAssertEqual(quantityUsed, 10, accuracy: 0.00001)
    XCTAssertEqual(matches.count, 2)
    XCTAssertEqual(matches.reduce(Decimal(0)) { $0 + $1.quantity }, 10, accuracy: 0.00001)
    XCTAssertEqual(matches.reduce(Decimal(0)) { $0 + $1.cost }, 555, accuracy: 0.00001)
    XCTAssertEqual(matches[0].quantity, 5, accuracy: 0.00001)
    XCTAssertEqual(matches[1].quantity, 5, accuracy: 0.00001)
  }

  func testReservesFutureBuyDayForItsOwnSameDayDisposalBeforeEarlier30DayMatching() {
    let earlySell = TestSupport.sell("16/12/2013", "BTC", 30, 10, 0)
    let sameDayBuyForEarlySell = TestSupport.buy("16/12/2013", "BTC", 10, 8, 0)
    let buyOnFutureSellDay = TestSupport.buy("18/12/2013", "BTC", 25, 9, 0)
    let futureSell = TestSupport.sell("18/12/2013", "BTC", 20, 11, 0)

    let (matches, quantityUsed) = BedAndBreakfastMatcher.findMatches(
      for: earlySell,
      from: [sameDayBuyForEarlySell, buyOnFutureSellDay],
      usedBuyQuantities: [:],
      sortedEvents: [],
      allSells: [earlySell, futureSell])

    XCTAssertEqual(quantityUsed, 15, accuracy: 0.00001)
    XCTAssertEqual(matches.count, 2)
    XCTAssertEqual(matches[0].buyTransaction.id, sameDayBuyForEarlySell.id)
    XCTAssertEqual(matches[0].buyDateQuantity, 10, accuracy: 0.00001)
    XCTAssertEqual(matches[1].buyTransaction.id, buyOnFutureSellDay.id)
    XCTAssertEqual(matches[1].buyDateQuantity, 5, accuracy: 0.00001)
  }

  func testReservesFutureDayBuysProRataAcrossMultipleLots() {
    let earlySell = TestSupport.sell("10/01/2020", "TEST", 40, 10, 0)
    let futureDayBuyA = TestSupport.buy("20/01/2020", "TEST", 30, 2, 0, sourceOrder: 0)
    let futureDayBuyB = TestSupport.buy("20/01/2020", "TEST", 70, 4, 0, sourceOrder: 1)
    let futureSell = TestSupport.sell("20/01/2020", "TEST", 60, 11, 0)

    let (matches, quantityUsed) = BedAndBreakfastMatcher.findMatches(
      for: earlySell,
      from: [futureDayBuyA, futureDayBuyB],
      usedBuyQuantities: [:],
      sortedEvents: [],
      allSells: [earlySell, futureSell])

    XCTAssertEqual(quantityUsed, 40, accuracy: 0.00001)
    XCTAssertEqual(matches.count, 2)
    XCTAssertEqual(matches[0].buyTransaction.id, futureDayBuyA.id)
    XCTAssertEqual(matches[0].buyDateQuantity, 12, accuracy: 0.00001)
    XCTAssertEqual(matches[0].cost, 24, accuracy: 0.00001)
    XCTAssertEqual(matches[1].buyTransaction.id, futureDayBuyB.id)
    XCTAssertEqual(matches[1].buyDateQuantity, 28, accuracy: 0.00001)
    XCTAssertEqual(matches[1].cost, 112, accuracy: 0.00001)
  }

  func testAdjustedQuantityIgnoresNonRestructureEvents() {
    let sellDate = TestSupport.date("01/06/2019")
    let rebuy = TestSupport.buy("10/06/2019", "TEST", 200, 5, 0)
    let events = [
      TestSupport.capReturn("05/06/2019", "TEST", 200, 10),
      TestSupport.dividend("06/06/2019", "TEST", 200, 10)
    ]

    let adjustedQuantity = BedAndBreakfastMatcher.adjustedQuantity(
      for: rebuy,
      relativeTo: sellDate,
      sortedEvents: events)

    XCTAssertEqual(adjustedQuantity, 200)
  }

  func testEventAdjustmentExcludesEventsAfterEndDate() {
    let buy = TestSupport.buy("01/06/2019", "TEST", 100, 10, 0)
    let endDate = TestSupport.date("15/06/2019")
    let events = [
      TestSupport.dividend("10/06/2019", "TEST", 100, 20),
      TestSupport.capReturn("20/06/2019", "TEST", 100, 10)
    ]

    let adjustment = BedAndBreakfastMatcher.eventAdjustment(
      for: buy,
      through: endDate,
      sortedEvents: events,
      matchedBuyQuantity: 100)

    XCTAssertEqual(adjustment, 20, accuracy: 0.00001)
  }

  func testSameDayBuyOrderingUsesTimestampBeforeSourceOrder() throws {
    let sell = TestSupport.sell("01/06/2019", "TEST", 100, 12, 0)
    let dayStart = TestSupport.date("01/06/2019")
    let earlierTime = dayStart
    let laterTime = try XCTUnwrap(UTC.calendar.date(byAdding: .hour, value: 1, to: dayStart))

    let buyLater = Transaction(
      sourceOrder: 0,
      type: .buy,
      date: laterTime,
      asset: "TEST",
      quantity: 50,
      price: 10,
      expenses: 0)
    let buyEarlier = Transaction(
      sourceOrder: 1,
      type: .buy,
      date: earlierTime,
      asset: "TEST",
      quantity: 50,
      price: 10,
      expenses: 0)

    let (matches, quantityUsed) = BedAndBreakfastMatcher.findMatches(
      for: sell,
      from: [buyLater, buyEarlier],
      usedBuyQuantities: [:],
      sortedEvents: [],
      allSells: [sell])

    XCTAssertEqual(quantityUsed, 100, accuracy: 0.00001)
    XCTAssertEqual(matches.count, 2)
    XCTAssertEqual(matches[0].buyTransaction.id, buyEarlier.id)
    XCTAssertEqual(matches[1].buyTransaction.id, buyLater.id)
  }
}
