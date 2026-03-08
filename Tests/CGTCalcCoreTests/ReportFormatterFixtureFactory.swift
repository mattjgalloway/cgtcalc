@testable import CGTCalcCore
import Foundation

enum ReportFormatterFixtureFactory {
  static func makeResult(transactionCount: Int = 2) -> CalculationResult {
    let taxYear = TaxYear(startYear: 2023)
    let buy = Transaction(type: .buy, date: self.date("01/05/2023"), asset: "FOO", quantity: 200, price: 8, expenses: 2)
    let sell = Transaction(
      type: .sell,
      date: self.date("01/06/2023"),
      asset: "FOO",
      quantity: 100,
      price: 12,
      expenses: 3)
    let disposal = Disposal(
      sellTransaction: sell,
      taxYear: taxYear,
      gain: 395,
      section104Matches: [
        Section104Match(
          transactionId: buy.id,
          quantity: 100,
          cost: 800,
          date: buy.date,
          poolQuantity: 200,
          poolCost: 1600)
      ],
      bedAndBreakfastMatches: [])
    let summary = TaxYearSummary(
      taxYear: taxYear,
      disposals: [disposal],
      totalGain: 395,
      totalLoss: 0,
      netGain: 395,
      exemption: 6000,
      taxableGain: 0,
      lossCarryForward: 0)

    let transactions: [Transaction] = if transactionCount <= 2 {
      [buy, sell]
    } else {
      (0 ..< transactionCount).map { index in
        let type: TransactionType = index.isMultiple(of: 2) ? .buy : .sell
        let day = 1 + (index % 28)
        return Transaction(
          type: type,
          date: self.date(String(format: "%02d/07/2023", day)),
          asset: "FOO",
          quantity: 1 + Decimal(index % 7),
          price: 10 + Decimal(index % 5),
          expenses: 1)
      }
    }

    return CalculationResult(
      taxYearSummaries: [summary],
      transactions: transactions,
      assetEvents: [],
      lossCarryForward: 0,
      holdings: [
        "FOO": Section104Holding(quantity: 100, costBasis: 800, pool: [])
      ])
  }

  private static func date(_ value: String) -> Date {
    try! DateParser.parse(value)
  }
}
