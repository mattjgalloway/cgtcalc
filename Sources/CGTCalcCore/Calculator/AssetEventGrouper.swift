import Foundation

enum AssetEventGrouper {
  private struct DistributionKey: Hashable {
    let asset: String
    let day: Date
    let type: AssetEventType
  }

  static func groupDistributions(_ events: [AssetEvent]) -> [AssetEvent] {
    let totals = Dictionary(grouping: events.compactMap { event -> (DistributionKey, AssetEvent)? in
      guard let type = event.distributionType else { return nil }
      return (
        DistributionKey(asset: event.asset, day: UTC.calendar.startOfDay(for: event.date), type: type),
        event)
    }, by: \.0)

    var emittedKeys: Set<DistributionKey> = []
    return events.compactMap { event in
      guard let type = event.distributionType else { return event }
      let key = DistributionKey(asset: event.asset, day: UTC.calendar.startOfDay(for: event.date), type: type)
      guard emittedKeys.insert(key).inserted else { return nil }

      let groupedEvents = totals[key, default: []].map(\.1)
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
    }
  }
}
