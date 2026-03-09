import Foundation

// MARK: - Asset Event Validator

enum AssetEventValidator {
  private static let amountTolerance = Decimal(string: "0.00000001") ?? Decimal(0)

  /// Validates CAPRETURN and DIVIDEND amounts against the actual holding state for one asset.
  /// - Parameters:
  ///   - transactions: Buy and sell transactions for one asset.
  ///   - assetEvents: Asset events for the same asset.
  static func validate(transactions: [Transaction], assetEvents: [AssetEvent]) throws {
    let actions = (
      transactions.map(Action.transaction) +
        assetEvents.map(Action.event)).sorted(by: self.actionSortsBefore)

    var holding = Holding()

    for actionsOnDate in Dictionary(grouping: actions, by: \.date)
      .sorted(by: { $0.key < $1.key })
      .map(\.value)
    {
      try self.validateDistributionAmounts(in: actionsOnDate, against: holding)

      for action in actionsOnDate {
        switch action {
        case .transaction(let transaction):
          switch transaction.type {
          case .buy:
            holding.quantity += transaction.quantity
            holding.pool.append(PoolEntry(
              transactionId: transaction.id,
              sourceOrder: transaction.sourceOrder,
              quantity: transaction.quantity,
              date: transaction.date))
          case .sell:
            holding.quantity = max(0, holding.quantity - transaction.quantity)
            holding.pool = self.depletingPool(holding.pool, by: transaction.quantity)
          }

        case .event(let event):
          if let ratio = event.restructureRatio {
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
  }

  private static func validateDistributionAmounts(in actions: [Action], against holding: Holding) throws {
    // Same-day distribution rows are validated as one logical event per type.
    let events = actions.compactMap { action -> AssetEvent? in
      guard case .event(let event) = action else { return nil }
      return event
    }

    let totalDividendAmount = events
      .filter { $0.type == .dividend }
      .reduce(Decimal(0)) { partial, event in
        partial + (event.distribution?.amount ?? 0)
      }
    if totalDividendAmount > 0 {
      try self.validateDistributionAmount(
        asset: events[0].asset,
        date: events[0].date,
        type: .dividend,
        expected: holding.quantity,
        actual: totalDividendAmount)
    }

    let totalCapitalReturnAmount = events
      .filter { $0.type == .capitalReturn }
      .reduce(Decimal(0)) { partial, event in
        partial + (event.distribution?.amount ?? 0)
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
    }
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
    abs(lhs - rhs) <= self.amountTolerance
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
    if lhs.date != rhs.date {
      return lhs.date < rhs.date
    }

    if lhs.sourceOrder != rhs.sourceOrder {
      return (lhs.sourceOrder ?? .max) < (rhs.sourceOrder ?? .max)
    }

    if lhs.typeRank != rhs.typeRank {
      return lhs.typeRank < rhs.typeRank
    }

    return lhs.id.uuidString < rhs.id.uuidString
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

    var typeRank: Int {
      switch self {
      case .transaction(let transaction):
        transaction.type == .buy ? 0 : 1
      case .event:
        2
      }
    }

    var isDistributionEvent: Bool {
      switch self {
      case .transaction:
        false
      case .event(let event):
        event.type == .capitalReturn || event.type == .dividend
      }
    }
  }
}
