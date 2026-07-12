import Foundation

// MARK: - Asset Event Validator

enum AssetEventValidator {
  private static let absoluteAmountTolerance = Decimal.parse("0.0001") ?? Decimal(0)
  private static let relativeAmountTolerance = Decimal.parse("0.00001") ?? Decimal(0)

  /// Validates CAPRETURN and DIVIDEND amounts against the actual holding state for one asset.
  /// - Parameters:
  ///   - transactions: Buy and sell transactions for one asset.
  ///   - assetEvents: Asset events for the same asset.
  static func validate(transactions: [Transaction], assetEvents: [AssetEvent]) throws {
    _ = try self.eligibleAmounts(transactions: transactions, assetEvents: assetEvents)
  }

  /// Validates distribution quantities and replaces accepted broker-rounded amounts with the eligible quantity used
  /// for cost-basis apportionment.
  static func normalizingGroupedDistributionAmounts(
    transactions: [Transaction],
    assetEvents: [AssetEvent]) throws -> [AssetEvent]
  {
    let eligibleAmounts = try self.eligibleAmounts(transactions: transactions, assetEvents: assetEvents)
    return assetEvents.map { event in
      guard let eligibleAmount = eligibleAmounts[event.id] else { return event }
      let kind: AssetEvent.Kind = switch event.kind {
      case .capitalReturn(_, let value):
        .capitalReturn(amount: eligibleAmount, value: value)
      case .dividend(_, let value):
        .dividend(amount: eligibleAmount, value: value)
      case .split, .unsplit, .restruct:
        event.kind
      }
      return AssetEvent(
        id: event.id,
        sourceOrder: event.sourceOrder,
        date: event.date,
        asset: event.asset,
        kind: kind)
    }
  }

  private static func eligibleAmounts(
    transactions: [Transaction],
    assetEvents: [AssetEvent]) throws -> [UUID: Decimal]
  {
    let actions = (
      transactions.map(Action.transaction) +
        assetEvents.map(Action.event)).sorted(by: self.actionSortsBefore)

    var holding = Holding()
    var eligibleAmounts: [UUID: Decimal] = [:]

    for actionsOnDate in Dictionary(grouping: actions, by: \.date)
      .sorted(by: { $0.key < $1.key })
      .map(\.value)
    {
      try eligibleAmounts.merge(
        self.validateDistributionAmounts(in: actionsOnDate, against: holding),
        uniquingKeysWith: { _, latest in latest })

      for action in actionsOnDate {
        switch action {
        case .transaction(let transaction):
          switch transaction.type {
          case .buy, .spouseIn:
            holding.quantity += transaction.quantity
            holding.pool.append(PoolEntry(
              transactionId: transaction.id,
              sourceOrder: transaction.sourceOrder,
              quantity: transaction.quantity,
              date: transaction.date))
          case .sell, .spouseOut:
            holding.quantity = max(0, holding.quantity - transaction.quantity)
            holding.pool = self.depletingPool(holding.pool, by: transaction.quantity)
          }

        case .event(let event):
          let ratio: (oldUnits: Decimal, newUnits: Decimal)? = switch event.kind {
          case .split(let multiplier):
            (oldUnits: 1, newUnits: multiplier)
          case .unsplit(let multiplier):
            (oldUnits: multiplier, newUnits: 1)
          case .restruct(let oldUnits, let newUnits):
            (oldUnits: oldUnits, newUnits: newUnits)
          case .capitalReturn, .dividend:
            nil
          }

          if let ratio {
            holding.quantity = holding.quantity * ratio.newUnits / ratio.oldUnits
            holding.pool = holding.pool.map { entry in
              PoolEntry(
                transactionId: entry.transactionId,
                sourceOrder: entry.sourceOrder,
                quantity: entry.quantity * ratio.newUnits / ratio.oldUnits,
                date: entry.date)
            }
          }
        }
      }

      if actionsOnDate.contains(where: \.isDistributionEvent) {
        holding.lastDistributionDate = actionsOnDate[0].date
      }
    }
    return eligibleAmounts
  }

  private static func validateDistributionAmounts(
    in actions: [Action],
    against holding: Holding) throws -> [UUID: Decimal]
  {
    // Same-day distribution rows are validated as one logical event per type.
    let events = actions.compactMap { action -> AssetEvent? in
      guard case .event(let event) = action else { return nil }
      return event
    }
    var eligibleAmounts: [UUID: Decimal] = [:]

    let totalDividendAmount = events
      .filter { event in
        if case .dividend = event.kind {
          return true
        }
        return false
      }
      .reduce(Decimal(0)) { partial, event in
        if case .dividend(let amount, _) = event.kind {
          return partial + amount
        }
        return partial
      }
    if totalDividendAmount > 0 {
      guard holding.quantity > 0 else {
        throw CalculationError.invalidAssetEventAmount(
          asset: events[0].asset,
          date: events[0].date,
          type: .dividend,
          expected: 0,
          actual: totalDividendAmount)
      }
      try self.validateDistributionAmount(
        asset: events[0].asset,
        date: events[0].date,
        type: .dividend,
        expected: holding.quantity,
        actual: totalDividendAmount)
      for event in events where event.distributionType == .dividend {
        eligibleAmounts[event.id] = holding.quantity
      }
    }

    let totalCapitalReturnAmount = events
      .filter { event in
        if case .capitalReturn = event.kind {
          return true
        }
        return false
      }
      .reduce(Decimal(0)) { partial, event in
        if case .capitalReturn(let amount, _) = event.kind {
          return partial + amount
        }
        return partial
      }
    if totalCapitalReturnAmount > 0 {
      let expectedQuantity = holding.pool
        .filter { entry in
          guard let lastDistributionDate = holding.lastDistributionDate else { return true }
          return entry.date > lastDistributionDate
        }
        .reduce(Decimal(0)) { $0 + $1.quantity }

      try self.validateDistributionAmount(
        asset: events[0].asset,
        date: events[0].date,
        type: .capitalReturn,
        expected: expectedQuantity,
        actual: totalCapitalReturnAmount)
      for event in events where event.distributionType == .capitalReturn {
        eligibleAmounts[event.id] = expectedQuantity
      }
    }
    return eligibleAmounts
  }

  private static func validateDistributionAmount(
    asset: String,
    date: Date,
    type: AssetEventType,
    expected: Decimal,
    actual: Decimal) throws
  {
    guard self.amountsMatch(expected, actual) else {
      throw CalculationError.invalidAssetEventAmount(
        asset: asset,
        date: date,
        type: type,
        expected: expected,
        actual: actual)
    }
  }

  private static func amountsMatch(_ lhs: Decimal, _ rhs: Decimal) -> Bool {
    let tolerance = max(self.absoluteAmountTolerance, abs(lhs) * self.relativeAmountTolerance)
    return abs(lhs - rhs) <= tolerance
  }

  private static func depletingPool(_ pool: [PoolEntry], by quantity: Decimal) -> [PoolEntry] {
    var remainingToUse = quantity
    var updatedPool = pool.sorted(by: self.poolSortsBefore)

    for index in updatedPool.indices where remainingToUse > 0 {
      let entry = updatedPool[index]
      let usedQuantity = min(remainingToUse, entry.quantity)
      updatedPool[index] = PoolEntry(
        transactionId: entry.transactionId,
        sourceOrder: entry.sourceOrder,
        quantity: max(0, entry.quantity - usedQuantity),
        date: entry.date)
      remainingToUse -= usedQuantity
    }

    return updatedPool
  }

  private static func actionSortsBefore(_ lhs: Action, _ rhs: Action) -> Bool {
    CalculationTimeline.entrySortsBefore(
      lhsDate: lhs.date,
      lhsPriority: lhs.timelinePriority,
      lhsSourceOrder: lhs.sourceOrder,
      lhsID: lhs.id,
      rhsDate: rhs.date,
      rhsPriority: rhs.timelinePriority,
      rhsSourceOrder: rhs.sourceOrder,
      rhsID: rhs.id)
  }

  private static func poolSortsBefore(_ lhs: PoolEntry, _ rhs: PoolEntry) -> Bool {
    if lhs.date != rhs.date {
      return lhs.date < rhs.date
    }
    if lhs.sourceOrder != rhs.sourceOrder {
      return (lhs.sourceOrder ?? .max) < (rhs.sourceOrder ?? .max)
    }
    return lhs.transactionId.uuidString < rhs.transactionId.uuidString
  }

  private struct Holding {
    var quantity: Decimal = 0
    var pool: [PoolEntry] = []
    var lastDistributionDate: Date?
  }

  private struct PoolEntry {
    let transactionId: UUID
    let sourceOrder: Int?
    let quantity: Decimal
    let date: Date
  }

  private enum Action {
    case transaction(Transaction)
    case event(AssetEvent)

    var id: UUID {
      switch self {
      case .transaction(let transaction):
        transaction.id
      case .event(let event):
        event.id
      }
    }

    var date: Date {
      switch self {
      case .transaction(let transaction):
        transaction.date
      case .event(let event):
        event.date
      }
    }

    var sourceOrder: Int? {
      switch self {
      case .transaction(let transaction):
        transaction.sourceOrder
      case .event(let event):
        event.sourceOrder
      }
    }

    var timelinePriority: Int {
      switch self {
      case .transaction(let transaction):
        CalculationTimeline.priority(for: transaction)
      case .event(let event):
        CalculationTimeline.priority(for: event)
      }
    }

    var isDistributionEvent: Bool {
      switch self {
      case .transaction:
        false
      case .event(let event):
        switch event.kind {
        case .capitalReturn, .dividend:
          true
        case .split, .unsplit, .restruct:
          false
        }
      }
    }
  }
}
