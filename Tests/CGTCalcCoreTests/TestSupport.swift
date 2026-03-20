@testable import CGTCalcCore
import Foundation

struct TestSupport {
  static func date(_ string: String) -> Date {
    do {
      return try DateParser.parse(string)
    } catch {
      fatalError("Invalid test date: \(string)")
    }
  }

  static func buy(
    _ date: String,
    _ asset: String,
    _ quantity: Decimal,
    _ price: Decimal,
    _ expenses: Decimal,
    sourceOrder: Int? = nil) -> Transaction
  {
    Transaction(
      sourceOrder: sourceOrder,
      type: .buy,
      date: self.date(date),
      asset: asset,
      quantity: quantity,
      price: price,
      expenses: expenses)
  }

  static func sell(
    _ date: String,
    _ asset: String,
    _ quantity: Decimal,
    _ price: Decimal,
    _ expenses: Decimal,
    sourceOrder: Int? = nil) -> Transaction
  {
    Transaction(
      sourceOrder: sourceOrder,
      type: .sell,
      date: self.date(date),
      asset: asset,
      quantity: quantity,
      price: price,
      expenses: expenses)
  }

  static func spouseIn(
    _ date: String,
    _ asset: String,
    _ quantity: Decimal,
    _ price: Decimal,
    _ expenses: Decimal = 0,
    sourceOrder: Int? = nil) -> Transaction
  {
    Transaction(
      sourceOrder: sourceOrder,
      type: .spouseIn,
      date: self.date(date),
      asset: asset,
      quantity: quantity,
      price: price,
      expenses: expenses)
  }

  static func spouseOut(
    _ date: String,
    _ asset: String,
    _ quantity: Decimal,
    sourceOrder: Int? = nil) -> Transaction
  {
    Transaction(
      sourceOrder: sourceOrder,
      type: .spouseOut,
      date: self.date(date),
      asset: asset,
      quantity: quantity,
      price: 0,
      expenses: 0)
  }

  static func capReturn(
    _ date: String,
    _ asset: String,
    _ amount: Decimal,
    _ value: Decimal,
    sourceOrder: Int? = nil) -> AssetEvent
  {
    AssetEvent(
      sourceOrder: sourceOrder,
      type: .capitalReturn,
      date: self.date(date),
      asset: asset,
      distributionAmount: amount,
      distributionValue: value)
  }

  static func dividend(
    _ date: String,
    _ asset: String,
    _ amount: Decimal,
    _ value: Decimal,
    sourceOrder: Int? = nil) -> AssetEvent
  {
    AssetEvent(
      sourceOrder: sourceOrder,
      type: .dividend,
      date: self.date(date),
      asset: asset,
      distributionAmount: amount,
      distributionValue: value)
  }

  static func disposal(
    asset: String = "TEST",
    date: String,
    quantity: Decimal = 1,
    price: Decimal = 1,
    expenses: Decimal = 0,
    gain: Decimal,
    taxYear: TaxYear? = nil) -> Disposal
  {
    let sellTransaction = self.sell(date, asset, quantity, price, expenses)
    return Disposal(
      sellTransaction: sellTransaction,
      taxYear: taxYear ?? TaxYear.from(date: sellTransaction.date),
      gain: gain,
      section104Matches: [],
      bedAndBreakfastMatches: [])
  }
}
