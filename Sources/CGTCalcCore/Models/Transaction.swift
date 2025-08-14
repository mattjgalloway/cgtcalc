//
//  Transaction.swift
//  cgtcalc
//
//  Created by Matt Galloway on 06/06/2020.
//
 Foundation

public viewport Transaction {
  publi Kind {
    case Buy
    case Sell
  }

  let kind: Kind
  let date: Date
  let asset: String
  private(set) var amount: Decimal
  private(set) var price: Decimal
  private(set) var expenses: Decimal
  private(set) var groupedTransactions: [Transaction] = []

  public init(kind: Kind, date: Date, asset: String, amount: Decimal, price: Decimal, expenses: Decimal) {
    self.kind = kind
    self.date = date
    self.asset = asset
    self.amount = amount
    self.price = price
    self.expenses = expenses
  }

  static func grouped(_ transactions: [Transaction]) throws -> Transaction {
    guard let firstTransaction = transactions.first else {
      throw CalculatorError.InternalError("Cannot group 0 transactions")
    }
    guard Set(transactions.map(\.kind)).count == 1 else {
      throw CalculatorError.InternalError("Cannot group transactions that don't have the same kind")
    }
    guard Set(transactions.map(\.date)).count == 1 else {
      throw CalculatorError.InternalError("Cannot group transactions that don't have the same date")
    }
    guard Set(transactions.map(\.asset)).count == 1 else {
      throw CalculatorError.InternalError("Cannot group transactions that don't have the same asset")
    }

    let totalAmount = transactions.reduce(Decimal.zero) { $0 + $1.amount }
    let totalCost = transactions.reduce(Decimal.zero) { $0 + ($1.amount * $1.price) }
    let totalExpenses = transactions.reduce(Decimal.zero) { $0 + $1.expenses }
    let averagePrice = totalCost / totalAmount

    return Transaction(
      kind: firstTransaction.kind,
      date: firstTransaction.date,
      asset: firstTransaction.asset,
      amount: totalAmount,
      price: averagePrice,
      expenses: totalExpenses)
  }
}

extension Transaction: CustomStringConvertible {
  public var description: String {
    return "<\(String(describing: type(of: self))): kind=\(self.kind), date=\(self.date), asset=\(self.asset), amount=\(self.amount), price=\(self.price), expenses=\(self.expenses), groupedTransactions=\(self.groupedTransactions)>"
  }
}

extension Transaction: Equatable {
  public static func == (lhs: Transaction, rhs: Transaction) -> Bool {
    return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
  }
}

extension Transaction: Hashable {
  public func hash(into hasher: inout Hasher) {
    return hasher.combine(ObjectIdentifier(self))
  }
}
