import Foundation

enum SameDateInputValidator {
  private struct Key: Hashable {
    let asset: String
    let day: Date
  }

  static func validate(transactions: [Transaction], assetEvents: [AssetEvent]) throws {
    var rowTypesByKey: [Key: [String]] = [:]
    var acquisitionCountByKey: [Key: Int] = [:]
    var outboundCountByKey: [Key: Int] = [:]
    var distributionCountByKey: [Key: Int] = [:]
    var restructureCountByKey: [Key: Int] = [:]

    for transaction in transactions {
      let key = Key(asset: transaction.asset, day: UTC.calendar.startOfDay(for: transaction.date))
      rowTypesByKey[key, default: []].append(transaction.type.rawValue)
      if transaction.type.isAcquisition {
        acquisitionCountByKey[key, default: 0] += 1
      } else {
        outboundCountByKey[key, default: 0] += 1
      }
    }
    for event in assetEvents {
      let key = Key(asset: event.asset, day: UTC.calendar.startOfDay(for: event.date))
      let type = event.type
      rowTypesByKey[key, default: []].append(type.rawValue)
      if event.distributionType == nil {
        restructureCountByKey[key, default: 0] += 1
      } else {
        distributionCountByKey[key, default: 0] += 1
      }
    }

    for key in rowTypesByKey.keys.sorted(by: self.keySortsBefore) {
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

  private static func keySortsBefore(_ lhs: Key, _ rhs: Key) -> Bool {
    if lhs.day != rhs.day { return lhs.day < rhs.day }
    return lhs.asset < rhs.asset
  }
}
