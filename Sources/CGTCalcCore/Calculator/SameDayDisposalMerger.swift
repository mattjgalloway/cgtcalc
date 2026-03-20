import Foundation

// MARK: - Same-Day Disposal Merger

enum SameDayDisposalMerger {
  /// Merges same-asset sells on the same day into one effective disposal before matching and rounding.
  /// - Parameter transactions: Input transactions in source order.
  /// - Returns: Sell transactions merged by asset/day, with other transactions unchanged in effect.
  static func merge(_ transactions: [Transaction]) -> [Transaction] {
    struct SellGroupKey: Hashable {
      let asset: String
      let day: Date
    }

    struct SellGroup {
      let firstIndex: Int
      var sells: [Transaction]
    }

    let calendar = UTC.calendar
    var groupedSells: [SellGroupKey: SellGroup] = [:]

    for (index, transaction) in transactions.enumerated() where transaction.type == .sell {
      let key = SellGroupKey(
        asset: transaction.asset,
        day: calendar.startOfDay(for: transaction.date))

      if var existingGroup = groupedSells[key] {
        existingGroup.sells.append(transaction)
        groupedSells[key] = existingGroup
      } else {
        groupedSells[key] = SellGroup(firstIndex: index, sells: [transaction])
      }
    }

    return groupedSells.values
      .sorted { lhs, rhs in
        let lhsDate = lhs.sells[0].date
        let rhsDate = rhs.sells[0].date
        if lhsDate != rhsDate {
          return lhsDate < rhsDate
        }
        return lhs.firstIndex < rhs.firstIndex
      }
      .map { group in
        guard group.sells.count > 1 else { return group.sells[0] }

        let quantity = group.sells.reduce(Decimal(0)) { $0 + $1.quantity }
        let proceeds = group.sells.reduce(Decimal(0)) { $0 + $1.proceeds }
        let expenses = group.sells.reduce(Decimal(0)) { $0 + $1.expenses }
        let weightedPrice = quantity > 0 ? proceeds / quantity : 0
        let firstSell = group.sells[0]

        return Transaction(
          sourceOrder: firstSell.sourceOrder,
          type: .sell,
          date: firstSell.date,
          asset: firstSell.asset,
          quantity: quantity,
          price: weightedPrice,
          expenses: expenses)
      }
  }
}
