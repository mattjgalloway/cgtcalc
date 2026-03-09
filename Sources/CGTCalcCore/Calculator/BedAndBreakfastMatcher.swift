import Foundation

// MARK: - Bed and Breakfast Matcher

enum BedAndBreakfastMatcher {
  /// Returns same-day and 30-day rebuy matches for a sell, plus the total sell-date quantity matched.
  /// - Parameters:
  ///   - sell: The disposal being matched.
  ///   - buys: Candidate buys for the same asset.
  ///   - usedBuyQuantities: Buy-date quantities already consumed by earlier matches.
  ///   - sortedEvents: Asset events for the same asset in chronological order.
  /// - Returns: The matched rebuys and total quantity matched on the sell-date basis.
  static func findMatches(
    for sell: Transaction,
    from buys: [Transaction],
    usedBuyQuantities: [UUID: Decimal],
    sortedEvents: [AssetEvent],
    allSells: [Transaction]) -> ([BedAndBreakfastMatch], Decimal)
  {
    var bnbMatches: [BedAndBreakfastMatch] = []
    var totalQuantityMatched: Decimal = 0
    var remainingToMatch = sell.quantity

    let asset = sell.asset
    let sellDate = sell.date

    let availableBuys = buys.filter { buy in
      buy.asset == asset &&
        buy.id != sell.id
    }

    let sameDayBuys = availableBuys.filter { buy in
      UTC.calendar.isDate(buy.date, inSameDayAs: sellDate)
    }.sorted { $0.date < $1.date }

    for buyGroup in self.groupedBuysByDay(sameDayBuys) {
      guard remainingToMatch > 0 else { break }
      let groupResult = self.matchGroup(
        buyGroup,
        remainingToMatch: remainingToMatch,
        usedBuyQuantities: usedBuyQuantities,
        sellDate: sellDate,
        sortedEvents: sortedEvents)
      guard groupResult.quantityMatched > 0 else { continue }
      bnbMatches.append(contentsOf: groupResult.matches)
      totalQuantityMatched += groupResult.quantityMatched
      remainingToMatch -= groupResult.quantityMatched
    }

    let thirtyDaysAfter = UTC.calendar.date(byAdding: .day, value: 30, to: sellDate)!
    let windowBuys = availableBuys.filter { buy in
      buy.date > sellDate &&
        buy.date <= thirtyDaysAfter &&
        !UTC.calendar.isDate(buy.date, inSameDayAs: sellDate)
    }.sorted { $0.date < $1.date }

    let sellsByDay = Dictionary(grouping: allSells, by: { UTC.calendar.startOfDay(for: $0.date) })

    for buyGroup in self.groupedBuysByDay(windowBuys) {
      guard remainingToMatch > 0 else { break }
      let buyDay = UTC.calendar.startOfDay(for: buyGroup[0].date)
      let sameDaySellQuantity = sellsByDay[buyDay, default: []]
        .reduce(Decimal(0)) { total, sameDaySell in
          total + sameDaySell.quantity
        }
      let reservedByBuyID = self.reservedBuyDateQuantities(
        for: buyGroup,
        sameDaySellQuantity: sameDaySellQuantity)

      let groupResult = self.matchGroup(
        buyGroup,
        remainingToMatch: remainingToMatch,
        usedBuyQuantities: usedBuyQuantities,
        reservedBuyDateQuantities: reservedByBuyID,
        sellDate: sellDate,
        sortedEvents: sortedEvents)
      guard groupResult.quantityMatched > 0 else { continue }
      bnbMatches.append(contentsOf: groupResult.matches)
      totalQuantityMatched += groupResult.quantityMatched
      remainingToMatch -= groupResult.quantityMatched
    }

    return (bnbMatches, totalQuantityMatched)
  }

  /// Converts a rebuy quantity back to the sell-date share basis after any splits or reverse splits.
  /// - Parameters:
  ///   - buy: The rebuy transaction being matched.
  ///   - buyDateQuantity: Remaining quantity on the rebuy's own date basis.
  ///   - sellDate: The earlier disposal date.
  ///   - sortedEvents: Asset events for the same asset in chronological order.
  /// - Returns: The rebuy quantity expressed on the sell-date basis.
  static func adjustedQuantity(
    for buy: Transaction,
    buyDateQuantity: Decimal? = nil,
    relativeTo sellDate: Date,
    sortedEvents: [AssetEvent]) -> Decimal
  {
    var adjustedQuantity = buyDateQuantity ?? buy.quantity

    for event in self.restructureEvents(in: sortedEvents, after: sellDate, through: buy.date) {
      if let ratio = event.restructureRatio {
        adjustedQuantity = adjustedQuantity * ratio.oldUnits / ratio.newUnits
      }
    }

    return adjustedQuantity
  }

  /// Calculates post-buy CAPRETURN and DIVIDEND adjustments attributable to a matched rebuy quantity.
  /// - Parameters:
  ///   - buy: The rebuy transaction.
  ///   - endDate: Optional last date to include when scanning later events.
  ///   - sortedEvents: Asset events for the same asset in chronological order.
  ///   - matchedBuyQuantity: Quantity matched on the rebuy's own date basis.
  /// - Returns: The net cost-basis adjustment to add to the matched rebuy cost.
  static func eventAdjustment(
    for buy: Transaction,
    through endDate: Date?,
    sortedEvents: [AssetEvent],
    matchedBuyQuantity: Decimal) -> Decimal
  {
    guard matchedBuyQuantity > 0 else { return 0 }

    let relevantEvents = sortedEvents.filter { event in
      guard event.asset == buy.asset, event.date > buy.date else { return false }
      if let endDate, event.date > endDate {
        return false
      }
      return event.type == .capitalReturn || event.type == .dividend
    }

    return relevantEvents.reduce(Decimal(0)) { total, event in
      guard let distribution = event.distribution else { return total }
      let quantityRatio = matchedBuyQuantity / distribution.amount
      if event.type == .capitalReturn {
        return total - (distribution.value * quantityRatio)
      }
      return total + (distribution.value * quantityRatio)
    }
  }

  /// Filters restructure events between two dates for quantity-basis adjustment.
  /// - Parameters:
  ///   - events: Asset events to scan.
  ///   - startDate: Exclusive lower bound for event dates.
  ///   - endDate: Optional inclusive upper bound for event dates.
  /// - Returns: Relevant restructure events in their existing order.
  static func restructureEvents(
    in events: [AssetEvent],
    after startDate: Date,
    through endDate: Date?) -> [AssetEvent]
  {
    events.filter { event in
      guard event.date > startDate else { return false }
      if let endDate, event.date > endDate {
        return false
      }
      return event.isRestructure
    }
  }

  private static func groupedBuysByDay(_ buys: [Transaction]) -> [[Transaction]] {
    Dictionary(grouping: buys, by: { UTC.calendar.startOfDay(for: $0.date) })
      .sorted(by: { $0.key < $1.key })
      .map { _, buysOnDay in
        buysOnDay.sorted { lhs, rhs in
          if lhs.date != rhs.date {
            return lhs.date < rhs.date
          }
          if lhs.sourceOrder != rhs.sourceOrder {
            return (lhs.sourceOrder ?? .max) < (rhs.sourceOrder ?? .max)
          }
          return lhs.id.uuidString < rhs.id.uuidString
        }
      }
  }

  private static func matchGroup(
    _ buys: [Transaction],
    remainingToMatch: Decimal,
    usedBuyQuantities: [UUID: Decimal],
    reservedBuyDateQuantities: [UUID: Decimal] = [:],
    sellDate: Date,
    sortedEvents: [AssetEvent]) -> (matches: [BedAndBreakfastMatch], quantityMatched: Decimal)
  {
    struct AvailableBuy {
      let buy: Transaction
      let buyDateQuantityRemaining: Decimal
      let adjustedRemainingQuantity: Decimal
      let adjustedTotalQuantity: Decimal
    }

    let availableBuys = buys.compactMap { buy -> AvailableBuy? in
      let usedBuyDateQuantity = usedBuyQuantities[buy.id, default: 0]
      let reservedBuyDateQuantity = reservedBuyDateQuantities[buy.id, default: 0]
      let buyDateQuantityRemaining = max(0, buy.quantity - usedBuyDateQuantity - reservedBuyDateQuantity)
      guard buyDateQuantityRemaining > 0 else { return nil }

      let adjustedRemainingQuantity = self.adjustedQuantity(
        for: buy,
        buyDateQuantity: buyDateQuantityRemaining,
        relativeTo: sellDate,
        sortedEvents: sortedEvents)
      guard adjustedRemainingQuantity > 0 else { return nil }

      let adjustedTotalQuantity = self.adjustedQuantity(
        for: buy,
        relativeTo: sellDate,
        sortedEvents: sortedEvents)
      guard adjustedTotalQuantity > 0 else { return nil }

      return AvailableBuy(
        buy: buy,
        buyDateQuantityRemaining: buyDateQuantityRemaining,
        adjustedRemainingQuantity: adjustedRemainingQuantity,
        adjustedTotalQuantity: adjustedTotalQuantity)
    }

    let totalAdjustedQuantity = availableBuys.reduce(Decimal(0)) { $0 + $1.adjustedRemainingQuantity }
    guard totalAdjustedQuantity > 0 else {
      return ([], 0)
    }

    let actualMatchQty = min(remainingToMatch, totalAdjustedQuantity)
    let matches = availableBuys.compactMap { availableBuy -> BedAndBreakfastMatch? in
      let matchQuantity = actualMatchQty * availableBuy.adjustedRemainingQuantity / totalAdjustedQuantity
      guard matchQuantity > 0 else { return nil }

      let buyDateMatchQty = availableBuy.buyDateQuantityRemaining * matchQuantity / availableBuy
        .adjustedRemainingQuantity
      let eventAdjustment = self.eventAdjustment(
        for: availableBuy.buy,
        through: nil,
        sortedEvents: sortedEvents,
        matchedBuyQuantity: buyDateMatchQty)
      let actualCost = (availableBuy.buy.totalCost / availableBuy.adjustedTotalQuantity * matchQuantity) +
        eventAdjustment

      return BedAndBreakfastMatch(
        buyTransaction: availableBuy.buy,
        quantity: matchQuantity,
        buyDateQuantity: buyDateMatchQty,
        eventAdjustment: eventAdjustment,
        cost: actualCost)
    }

    return (matches, actualMatchQty)
  }

  /// Reserves a pro-rata portion of buys on a day for that day's same-day disposal before earlier disposals can use
  /// the remainder under 30-day matching.
  private static func reservedBuyDateQuantities(
    for buys: [Transaction],
    sameDaySellQuantity: Decimal) -> [UUID: Decimal]
  {
    guard sameDaySellQuantity > 0 else { return [:] }
    let totalBuyQuantity = buys.reduce(Decimal(0)) { $0 + $1.quantity }
    guard totalBuyQuantity > 0 else { return [:] }

    let totalReserved = min(sameDaySellQuantity, totalBuyQuantity)
    var reservedByBuyID: [UUID: Decimal] = [:]

    for buy in buys {
      let proRataReserved = totalReserved * buy.quantity / totalBuyQuantity
      reservedByBuyID[buy.id] = proRataReserved
    }

    return reservedByBuyID
  }
}
