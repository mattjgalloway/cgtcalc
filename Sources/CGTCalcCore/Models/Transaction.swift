//
//  Transaction.swift
//  cgtcalc
//
//  Created by Matt Galloway on 06/06/2020.
//

import Foundation

public class Transaction {
  enum Kind {
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

  init(kind: Kind, date: Date, asset: String, amount: Decimal, price: Decimal, expenses: Decimal) {
    self.kind = kind
    self.date = date
    self.asset = asset
    self.amount = amount
    self.price = price
    self.expenses = expenses
  }

  func groupWith(transaction: Transaction) throws {
    guard transaction.kind == self.kind, transaction.date == self.date, transaction.asset == self.asset else {
      throw CalculatorError.InternalError("Cannot group transactions that don't have the same kind, date and asset.")
    }
    let selfCost = self.amount * self.price
    let otherCost = transaction.amount * transaction.price
    self.amount += transaction.amount
    self.price = (selfCost + otherCost) / self.amount
    self.expenses += transaction.expenses
    self.groupedTransactions.append(transaction)
  }

  func groupWith(transactions: [Transaction]) throws {
    try transactions.forEach(self.groupWith(transaction:))
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
