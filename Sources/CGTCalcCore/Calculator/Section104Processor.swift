import Foundation

// MARK: - Section 104 Processor

enum Section104Processor {
  /// Builds the chronological stream of buys and asset events to replay into a Section 104 holding.
  /// - Parameters:
  ///   - buys: Candidate buys for one asset.
  ///   - events: Candidate asset events for the same asset.
  ///   - startDate: Exclusive lower bound for included actions.
  ///   - endDate: Optional inclusive upper bound for included actions.
  /// - Returns: Sorted actions with buys before events on the same date.
  static func actions(
    buys: [Transaction],
    events: [AssetEvent],
    after startDate: Date,
    through endDate: Date?) -> [Action]
  {
    let relevantBuys = buys.filter { buy in
      guard buy.date > startDate else { return false }
      if let endDate, buy.date > endDate {
        return false
      }
      return true
    }

    let relevantEvents = events.filter { event in
      guard event.date > startDate else { return false }
      if let endDate, event.date > endDate {
        return false
      }
      return true
    }

    return (
      relevantBuys.map(Action.buy) +
        relevantEvents.map(Action.event))
      .sorted(by: self.actionSortsBefore)
  }

  /// Replays buys and asset events into a holding while skipping already-matched buys and same-day sell buys.
  /// - Parameters:
  ///   - actions: Chronological actions to apply.
  ///   - holding: The starting Section 104 holding state.
  ///   - usedBuyQuantities: Buy-date quantities already used by same-day or B&B matching.
  /// - Returns: The updated holding after all actions are applied.
  static func processActions(
    _ actions: [Action],
    into holding: Section104Holding,
    usedBuyQuantities: [UUID: Decimal]) -> Section104Holding
  {
    var updatedHolding = holding

    for action in actions {
      switch action {
      case .buy(let buy):
        if updatedHolding.pool.contains(where: { $0.transactionId == buy.id }) { continue }
        let remainingQuantity = max(0, buy.quantity - usedBuyQuantities[buy.id, default: 0])
        guard remainingQuantity > 0 else { continue }
        let remainingCost = buy.totalCost * remainingQuantity / buy.quantity

        let match = Section104Match(
          transactionId: buy.id,
          sourceOrder: buy.sourceOrder,
          quantity: remainingQuantity,
          cost: remainingCost,
          date: buy.date,
          poolQuantity: updatedHolding.quantity,
          poolCost: updatedHolding.costBasis)
        updatedHolding.quantity += remainingQuantity
        updatedHolding.costBasis += remainingCost
        updatedHolding.pool.append(match)

      case .event(let event):
        updatedHolding = self.applyAssetEvent(event, to: updatedHolding)
      }
    }

    return updatedHolding
  }

  /// Prices a Section 104 disposal quantity using the current pool average cost.
  /// - Parameters:
  ///   - quantityNeeded: Quantity still to match after same-day and B&B rules.
  ///   - holding: The current Section 104 pool state.
  /// - Returns: Pool-provenance matches at the current average cost.
  static func makeMatches(quantityNeeded: Decimal, holding: Section104Holding) -> [Section104Match] {
    guard quantityNeeded > 0 else { return [] }

    let poolQuantity = holding.quantity
    let poolCostBasis = holding.costBasis
    let averageCost = poolQuantity > 0 ? poolCostBasis / poolQuantity : Decimal(0)
    var remainingQuantity = quantityNeeded
    var matches: [Section104Match] = []

    for match in holding.pool.sorted(by: self.matchSortsBefore) {
      guard remainingQuantity > 0, match.quantity > 0 else { continue }

      let matchQty = min(remainingQuantity, match.quantity)
      matches.append(Section104Match(
        transactionId: match.transactionId,
        sourceOrder: match.sourceOrder,
        quantity: matchQty,
        cost: matchQty * averageCost,
        date: match.date,
        poolQuantity: poolQuantity,
        poolCost: poolCostBasis))
      remainingQuantity -= matchQty
    }

    return matches
  }

  /// Removes matched Section 104 quantity and cost from the live holding.
  /// - Parameters:
  ///   - matches: Pool matches consumed by a disposal.
  ///   - holding: The holding to reduce.
  /// - Returns: The holding after quantity, cost basis, and pool entries are updated.
  static func applyMatches(_ matches: [Section104Match], to holding: Section104Holding) -> Section104Holding {
    guard !matches.isEmpty else { return holding }

    var updatedHolding = holding
    let totalUsed = matches.reduce(Decimal(0)) { $0 + $1.quantity }
    let matchedCost = matches.reduce(Decimal(0)) { $0 + $1.cost }
    updatedHolding.quantity -= totalUsed
    updatedHolding.costBasis -= matchedCost
    updatedHolding.pool = self.applyingMatches(matches, to: updatedHolding.pool)
    return updatedHolding
  }

  /// Applies a single asset event to a Section 104 holding.
  /// - Parameters:
  ///   - event: The event to apply.
  ///   - holding: The holding to update.
  /// - Returns: The adjusted holding.
  static func applyAssetEvent(_ event: AssetEvent, to holding: Section104Holding) -> Section104Holding {
    switch event.type {
    case .split, .unsplit, .restruct:
      return self.applyRestructureEvents([event], to: holding)
    case .capitalReturn:
      guard let distribution = event.distribution else { return holding }
      var adjustedHolding = holding
      adjustedHolding.costBasis = max(0, adjustedHolding.costBasis - distribution.value)
      return adjustedHolding
    case .dividend:
      guard let distribution = event.distribution else { return holding }
      var adjustedHolding = holding
      adjustedHolding.costBasis += distribution.value
      return adjustedHolding
    }
  }

  /// Applies one or more restructure events to a Section 104 holding and its pool provenance.
  /// - Parameters:
  ///   - events: Restructure events to apply in order.
  ///   - holding: The holding to update.
  /// - Returns: The adjusted holding with quantity-rescaled pool entries.
  static func applyRestructureEvents(_ events: [AssetEvent], to holding: Section104Holding) -> Section104Holding {
    var adjustedHolding = holding

    for event in events {
      if let ratio = event.restructureRatio {
        adjustedHolding.quantity = adjustedHolding.quantity * ratio.newUnits / ratio.oldUnits
        for i in 0 ..< adjustedHolding.pool.count {
          let match = adjustedHolding.pool[i]
          adjustedHolding.pool[i] = Section104Match(
            transactionId: match.transactionId,
            sourceOrder: match.sourceOrder,
            quantity: match.quantity * ratio.newUnits / ratio.oldUnits,
            cost: match.cost,
            date: match.date,
            poolQuantity: match.poolQuantity * ratio.newUnits / ratio.oldUnits,
            poolCost: match.poolCost)
        }
      }
    }

    return adjustedHolding
  }

  enum Action {
    case buy(Transaction)
    case event(AssetEvent)

    var date: Date {
      switch self {
      case .buy(let buy):
        buy.date
      case .event(let event):
        event.date
      }
    }
  }

  private static func actionSortsBefore(_ lhs: Action, _ rhs: Action) -> Bool {
    if lhs.date != rhs.date {
      return lhs.date < rhs.date
    }

    switch (lhs, rhs) {
    case (.buy, .event):
      return true
    case (.event, .buy):
      return false
    case (.buy(let lhsBuy), .buy(let rhsBuy)):
      if lhsBuy.sourceOrder != rhsBuy.sourceOrder {
        return (lhsBuy.sourceOrder ?? .max) < (rhsBuy.sourceOrder ?? .max)
      }
      return lhsBuy.id.uuidString < rhsBuy.id.uuidString
    case (.event(let lhsEvent), .event(let rhsEvent)):
      if lhsEvent.sourceOrder != rhsEvent.sourceOrder {
        return (lhsEvent.sourceOrder ?? .max) < (rhsEvent.sourceOrder ?? .max)
      }
      return lhsEvent.id.uuidString < rhsEvent.id.uuidString
    }
  }

  private static func matchSortsBefore(_ lhs: Section104Match, _ rhs: Section104Match) -> Bool {
    if lhs.date != rhs.date {
      return lhs.date < rhs.date
    }
    if lhs.sourceOrder != rhs.sourceOrder {
      return (lhs.sourceOrder ?? .max) < (rhs.sourceOrder ?? .max)
    }
    return lhs.transactionId.uuidString < rhs.transactionId.uuidString
  }

  private static func applyingMatches(_ matches: [Section104Match], to pool: [Section104Match]) -> [Section104Match] {
    let matchedQuantities = matches.reduce(into: [UUID: Decimal]()) { result, match in
      result[match.transactionId, default: 0] += match.quantity
    }

    return pool.map { poolMatch in
      let matchedQuantity = matchedQuantities[poolMatch.transactionId, default: 0]
      guard matchedQuantity > 0 else { return poolMatch }

      return Section104Match(
        transactionId: poolMatch.transactionId,
        sourceOrder: poolMatch.sourceOrder,
        quantity: max(0, poolMatch.quantity - matchedQuantity),
        cost: poolMatch.cost,
        date: poolMatch.date,
        poolQuantity: poolMatch.poolQuantity,
        poolCost: poolMatch.poolCost)
    }
  }
}
