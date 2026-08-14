import Foundation

// MARK: - Same-Day Acquisition Merger

enum SameDayAcquisitionMerger {
  /// Merges same-asset BUY transactions on the same day into one effective acquisition.
  /// SPOUSEIN rows are left unchanged because they carry an exact total cost that must
  /// not be combined with other lots.
  /// - Parameter transactions: Input transactions in source order.
  /// - Returns: BUY transactions merged by asset/day, with other transactions unchanged.
  static func merge(_ transactions: [Transaction]) -> [Transaction] {
    struct BuyGroupKey: Hashable {
      let asset: String
      let day: Date
    }

    struct BuyGroup {
      let firstIndex: Int
      var buys: [Transaction]
    }

    var groupedBuys: [BuyGroupKey: BuyGroup] = [:]

    for (index, transaction) in transactions.enumerated() where transaction.type == .buy {
      let key = BuyGroupKey(
        asset: transaction.asset,
        day: CalculationTimeline.day(for: transaction.date))

      if var existingGroup = groupedBuys[key] {
        existingGroup.buys.append(transaction)
        groupedBuys[key] = existingGroup
      } else {
        groupedBuys[key] = BuyGroup(firstIndex: index, buys: [transaction])
      }
    }

    // Build a set of transaction IDs that were merged into a group (with more than one row)
    // so we can exclude the originals from the output.
    var mergedIDs: Set<UUID> = []
    var mergedTransactions: [Transaction] = []

    for group in groupedBuys.values where group.buys.count > 1 {
      for buy in group.buys {
        mergedIDs.insert(buy.id)
      }

      let quantity = group.buys.reduce(Decimal(0)) { $0 + $1.quantity }
      let totalCost = group.buys.reduce(Decimal(0)) { $0 + $1.totalCost }
      let expenses = group.buys.reduce(Decimal(0)) { $0 + $1.expenses }
      let totalValue = totalCost - expenses
      let weightedPrice = quantity > 0 ? totalValue / quantity : 0
      let firstBuy = group.buys.sorted { ($0.sourceOrder ?? 0) < ($1.sourceOrder ?? 0) }[0]

      mergedTransactions.append(Transaction(
        sourceOrder: firstBuy.sourceOrder,
        type: .buy,
        date: firstBuy.date,
        asset: firstBuy.asset,
        quantity: quantity,
        price: weightedPrice,
        expenses: expenses,
        explicitTotalValue: totalValue))
    }

    let unmergedTransactions = transactions.filter { !mergedIDs.contains($0.id) }
    return (unmergedTransactions + mergedTransactions)
      .sorted { lhs, rhs in
        let lhsOrder = lhs.sourceOrder ?? Int.max
        let rhsOrder = rhs.sourceOrder ?? Int.max
        return lhsOrder < rhsOrder
      }
  }
}
