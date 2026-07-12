import Foundation

enum CalculationTimeline {
  struct DayKey: Hashable {
    let asset: String
    let day: Date
  }

  private struct DistributionKey: Hashable {
    let dayKey: DayKey
    let type: AssetEventType
  }

  static func day(for date: Date) -> Date {
    UTC.calendar.startOfDay(for: date)
  }

  static func dayKey(asset: String, date: Date) -> DayKey {
    DayKey(asset: asset, day: self.day(for: date))
  }

  static func validateSameDateCombinations(
    transactions: [Transaction],
    assetEvents: [AssetEvent]) throws
  {
    var rowTypesByKey: [DayKey: [String]] = [:]
    var acquisitionCountByKey: [DayKey: Int] = [:]
    var outboundCountByKey: [DayKey: Int] = [:]
    var distributionCountByKey: [DayKey: Int] = [:]
    var restructureCountByKey: [DayKey: Int] = [:]

    for transaction in transactions {
      let key = self.dayKey(asset: transaction.asset, date: transaction.date)
      rowTypesByKey[key, default: []].append(transaction.type.rawValue)
      if transaction.type.isAcquisition {
        acquisitionCountByKey[key, default: 0] += 1
      } else {
        outboundCountByKey[key, default: 0] += 1
      }
    }
    for event in assetEvents {
      let key = self.dayKey(asset: event.asset, date: event.date)
      rowTypesByKey[key, default: []].append(event.type.rawValue)
      if event.distributionType == nil {
        restructureCountByKey[key, default: 0] += 1
      } else {
        distributionCountByKey[key, default: 0] += 1
      }
    }

    for key in rowTypesByKey.keys.sorted(by: self.dayKeySortsBefore) {
      let hasTransactions = acquisitionCountByKey[key, default: 0] + outboundCountByKey[key, default: 0] > 0
      let hasAcquisitions = acquisitionCountByKey[key, default: 0] > 0
      let hasDistributions = distributionCountByKey[key, default: 0] > 0
      let restructureCount = restructureCountByKey[key, default: 0]
      let ambiguousDistributionEntitlement = hasDistributions && (hasTransactions || restructureCount > 0)
      let ambiguousRestructureBasis = restructureCount > 1 || (restructureCount == 1 && hasAcquisitions)
      guard !ambiguousDistributionEntitlement, !ambiguousRestructureBasis else {
        throw CalculationError.unsupportedSameDateCombination(
          asset: key.asset,
          date: key.day,
          rowTypes: rowTypesByKey[key, default: []].sorted())
      }
    }
  }

  static func groupDistributions(_ events: [AssetEvent]) -> [AssetEvent] {
    let grouped = Dictionary(grouping: events.compactMap { event -> (DistributionKey, AssetEvent)? in
      guard let type = event.distributionType else { return nil }
      return (DistributionKey(dayKey: self.dayKey(asset: event.asset, date: event.date), type: type), event)
    }, by: \.0)

    var emittedKeys: Set<DistributionKey> = []
    return events.compactMap { event in
      guard let type = event.distributionType else { return event }
      let key = DistributionKey(dayKey: self.dayKey(asset: event.asset, date: event.date), type: type)
      guard emittedKeys.insert(key).inserted else { return nil }

      let groupedEvents = grouped[key, default: []].map(\.1)
      let amount = groupedEvents.reduce(Decimal(0)) { $0 + $1.distributionAmount }
      let value = groupedEvents.reduce(Decimal(0)) { $0 + $1.distributionValue }
      let kind: AssetEvent.Kind = switch type {
      case .capitalReturn:
        .capitalReturn(amount: amount, value: value)
      case .dividend:
        .dividend(amount: amount, value: value)
      case .split, .unsplit, .restruct:
        preconditionFailure("Only distribution events can be grouped")
      }
      return AssetEvent(
        id: event.id,
        sourceOrder: event.sourceOrder,
        date: event.date,
        asset: event.asset,
        kind: kind)
    }.sorted(by: self.assetEventSortsBefore)
  }

  static func transactionSortsBefore(_ lhs: Transaction, _ rhs: Transaction) -> Bool {
    self.entrySortsBefore(
      lhsDate: lhs.date,
      lhsPriority: self.priority(for: lhs),
      lhsSourceOrder: lhs.sourceOrder,
      lhsID: lhs.id,
      rhsDate: rhs.date,
      rhsPriority: self.priority(for: rhs),
      rhsSourceOrder: rhs.sourceOrder,
      rhsID: rhs.id)
  }

  static func assetEventSortsBefore(_ lhs: AssetEvent, _ rhs: AssetEvent) -> Bool {
    if lhs.date != rhs.date { return lhs.date < rhs.date }
    if lhs.asset != rhs.asset { return lhs.asset < rhs.asset }
    return self.entrySortsBefore(
      lhsDate: lhs.date,
      lhsPriority: self.priority(for: lhs),
      lhsSourceOrder: lhs.sourceOrder,
      lhsID: lhs.id,
      rhsDate: rhs.date,
      rhsPriority: self.priority(for: rhs),
      rhsSourceOrder: rhs.sourceOrder,
      rhsID: rhs.id)
  }

  static func entrySortsBefore(
    lhsDate: Date,
    lhsPriority: Int,
    lhsSourceOrder: Int?,
    lhsID: UUID,
    rhsDate: Date,
    rhsPriority: Int,
    rhsSourceOrder: Int?,
    rhsID: UUID) -> Bool
  {
    if lhsDate != rhsDate { return lhsDate < rhsDate }
    if lhsPriority != rhsPriority { return lhsPriority < rhsPriority }
    if lhsSourceOrder != rhsSourceOrder { return (lhsSourceOrder ?? .max) < (rhsSourceOrder ?? .max) }
    return lhsID.uuidString < rhsID.uuidString
  }

  static func priority(for event: AssetEvent) -> Int {
    switch event.kind {
    case .dividend:
      2
    case .capitalReturn:
      3
    case .split, .unsplit, .restruct:
      4
    }
  }

  static func priority(for transaction: Transaction) -> Int {
    transaction.type.isAcquisition ? 0 : 1
  }

  private static func dayKeySortsBefore(_ lhs: DayKey, _ rhs: DayKey) -> Bool {
    if lhs.day != rhs.day { return lhs.day < rhs.day }
    return lhs.asset < rhs.asset
  }
}
