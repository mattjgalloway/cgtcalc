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
    usedBuyQuantities: [UUID: Decimal],
    allocatedEventValues: [UUID: Decimal] = [:],
    allocatedEventQuantities: [UUID: Decimal] = [:]) throws -> Section104Holding
  {
    var updatedHolding = holding

    for actionsOnDate in Dictionary(grouping: actions, by: \.date)
      .sorted(by: { $0.key < $1.key })
      .map({ $0.value.sorted(by: self.actionSortsBefore) })
    {
      for action in actionsOnDate {
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
          updatedHolding.groupIIEntries.append(GroupIICostEntry(
            transactionId: buy.id,
            sourceOrder: buy.sourceOrder,
            date: buy.date,
            quantity: remainingQuantity,
            cost: remainingCost))

        case .event(let event):
          let residualValue = max(0, event.distributionValue - allocatedEventValues[event.id, default: 0])
          let residualQuantity = max(0, event.distributionAmount - allocatedEventQuantities[event.id, default: 0])
          updatedHolding = try self.applyAssetEvent(
            event,
            value: residualValue,
            eligibleQuantity: residualQuantity,
            to: updatedHolding)
        }
      }

      if actionsOnDate.contains(where: \.isDistributionEvent) {
        updatedHolding.groupIIEntries = []
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
    let targetQuantity = min(quantityNeeded, poolQuantity)
    let targetCost = targetQuantity >= poolQuantity
      ? poolCostBasis
      : poolCostBasis * targetQuantity / poolQuantity
    var remainingQuantity = quantityNeeded
    var remainingCost = targetCost
    var cumulativeMatchedQuantity: Decimal = 0
    var matches: [Section104Match] = []

    for match in holding.pool.sorted(by: self.matchSortsBefore) {
      guard remainingQuantity > 0, match.quantity > 0 else { continue }

      let matchQty = min(remainingQuantity, match.quantity)
      cumulativeMatchedQuantity += matchQty
      let matchCost: Decimal = if cumulativeMatchedQuantity >= targetQuantity {
        remainingCost
      } else {
        poolCostBasis * matchQty / poolQuantity
      }
      matches.append(Section104Match(
        transactionId: match.transactionId,
        sourceOrder: match.sourceOrder,
        quantity: matchQty,
        cost: matchCost,
        date: match.date,
        poolQuantity: poolQuantity,
        poolCost: poolCostBasis))
      remainingQuantity -= matchQty
      remainingCost -= matchCost
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

  /// Removes physically outbound units from Group II provenance without changing the legal Section 104 pool.
  static func applyOutboundToGroupII(
    quantity: Decimal,
    holdingQuantity: Decimal,
    to holding: Section104Holding) -> Section104Holding
  {
    var updatedHolding = holding
    updatedHolding.groupIIEntries = self.depletingGroupIIEntries(
      holding.groupIIEntries,
      holdingQuantity: holdingQuantity,
      disposedQuantity: quantity)
    return updatedHolding
  }

  /// Applies a single asset event to a Section 104 holding.
  /// - Parameters:
  ///   - event: The event to apply.
  ///   - holding: The holding to update.
  /// - Returns: The adjusted holding.
  static func applyAssetEvent(_ event: AssetEvent, to holding: Section104Holding) throws -> Section104Holding {
    try self.applyAssetEvent(
      event,
      value: event.distributionValue,
      eligibleQuantity: event.distributionAmount,
      to: holding)
  }

  private static func applyAssetEvent(
    _ event: AssetEvent,
    value: Decimal,
    eligibleQuantity: Decimal,
    to holding: Section104Holding) throws -> Section104Holding
  {
    switch event.kind {
    case .split, .unsplit, .restruct:
      return self.applyRestructureEvents([event], to: holding)
    case .capitalReturn:
      var adjustedHolding = holding
      let availableCost = holding.groupIIEntries.reduce(Decimal(0)) { $0 + $1.cost }
      try CapitalReturnValidator.validate(
        asset: event.asset,
        date: event.date,
        value: value,
        availableCost: availableCost)
      adjustedHolding.costBasis = max(0, adjustedHolding.costBasis - value)
      adjustedHolding.groupIIEntries = self.applyingGroupIIAdjustment(-value, to: holding.groupIIEntries)
      return adjustedHolding
    case .dividend:
      var adjustedHolding = holding
      adjustedHolding.costBasis += value
      let groupIIQuantity = holding.groupIIEntries.reduce(Decimal(0)) { $0 + $1.quantity }
      let groupIIAdjustment = EventAllocationMath.proportionalValue(
        eventValue: value,
        destinationQuantity: groupIIQuantity,
        eligibleQuantity: eligibleQuantity)
      adjustedHolding.groupIIEntries = self.applyingGroupIIAdjustment(
        groupIIAdjustment,
        to: holding.groupIIEntries)
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
      switch event.kind {
      case .split(let multiplier):
        let ratio = (oldUnits: Decimal(1), newUnits: multiplier)
        adjustedHolding.quantity = adjustedHolding.quantity * ratio.newUnits / ratio.oldUnits
        self.rescaleGroupIIEntries(&adjustedHolding.groupIIEntries, by: ratio)
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
      case .unsplit(let multiplier):
        let ratio = (oldUnits: multiplier, newUnits: Decimal(1))
        adjustedHolding.quantity = adjustedHolding.quantity * ratio.newUnits / ratio.oldUnits
        self.rescaleGroupIIEntries(&adjustedHolding.groupIIEntries, by: ratio)
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
      case .restruct(let oldUnits, let newUnits):
        let ratio = (oldUnits: oldUnits, newUnits: newUnits)
        adjustedHolding.quantity = adjustedHolding.quantity * ratio.newUnits / ratio.oldUnits
        self.rescaleGroupIIEntries(&adjustedHolding.groupIIEntries, by: ratio)
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
      case .capitalReturn, .dividend:
        continue
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

    var isDistributionEvent: Bool {
      guard case .event(let event) = self else { return false }
      return event.distributionType != nil
    }

    var id: UUID {
      switch self {
      case .buy(let buy): buy.id
      case .event(let event): event.id
      }
    }

    var sourceOrder: Int? {
      switch self {
      case .buy(let buy): buy.sourceOrder
      case .event(let event): event.sourceOrder
      }
    }

    var priority: Int {
      switch self {
      case .buy: 0
      case .event(let event): CalculationTimeline.priority(for: event)
      }
    }
  }

  private static func actionSortsBefore(_ lhs: Action, _ rhs: Action) -> Bool {
    CalculationTimeline.entrySortsBefore(
      lhsDate: lhs.date,
      lhsPriority: lhs.priority,
      lhsSourceOrder: lhs.sourceOrder,
      lhsID: lhs.id,
      rhsDate: rhs.date,
      rhsPriority: rhs.priority,
      rhsSourceOrder: rhs.sourceOrder,
      rhsID: rhs.id)
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

  private static func depletingGroupIIEntries(
    _ entries: [GroupIICostEntry],
    holdingQuantity: Decimal,
    disposedQuantity: Decimal) -> [GroupIICostEntry]
  {
    let groupIIQuantity = entries.reduce(Decimal(0)) { $0 + $1.quantity }
    var remainingToDeplete = max(0, disposedQuantity - max(0, holdingQuantity - groupIIQuantity))
    var updatedEntries = entries.sorted(by: self.groupIIEntrySortsBefore)

    for index in updatedEntries.indices where remainingToDeplete > 0 {
      let quantityUsed = min(remainingToDeplete, updatedEntries[index].quantity)
      let costUsed = updatedEntries[index].quantity > 0
        ? updatedEntries[index].cost * quantityUsed / updatedEntries[index].quantity
        : 0
      updatedEntries[index].quantity -= quantityUsed
      updatedEntries[index].cost -= costUsed
      remainingToDeplete -= quantityUsed
    }
    return updatedEntries.filter { $0.quantity > 0 }
  }

  private static func applyingGroupIIAdjustment(
    _ adjustment: Decimal,
    to entries: [GroupIICostEntry]) -> [GroupIICostEntry]
  {
    let totalQuantity = entries.reduce(Decimal(0)) { $0 + $1.quantity }
    guard totalQuantity > 0 else { return entries }
    var remainingAdjustment = adjustment
    var adjustedEntries = entries
    for index in adjustedEntries.indices {
      let entryAdjustment = index == adjustedEntries.index(before: adjustedEntries.endIndex)
        ? remainingAdjustment
        : EventAllocationMath.proportionalValue(
          eventValue: abs(adjustment),
          destinationQuantity: adjustedEntries[index].quantity,
          eligibleQuantity: totalQuantity) * (adjustment < 0 ? -1 : 1)
      adjustedEntries[index].cost += entryAdjustment
      remainingAdjustment -= entryAdjustment
    }
    return adjustedEntries
  }

  private static func rescaleGroupIIEntries(
    _ entries: inout [GroupIICostEntry],
    by ratio: (oldUnits: Decimal, newUnits: Decimal))
  {
    for index in entries.indices {
      entries[index].quantity = entries[index].quantity * ratio.newUnits / ratio.oldUnits
    }
  }

  private static func groupIIEntrySortsBefore(_ lhs: GroupIICostEntry, _ rhs: GroupIICostEntry) -> Bool {
    if lhs.date != rhs.date { return lhs.date < rhs.date }
    if lhs.sourceOrder != rhs.sourceOrder { return (lhs.sourceOrder ?? .max) < (rhs.sourceOrder ?? .max) }
    return lhs.transactionId.uuidString < rhs.transactionId.uuidString
  }
}
