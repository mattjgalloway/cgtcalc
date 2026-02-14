//
//  MatchedTransaction.swift
//  cgtcalc
//
//  Created by Matt Galloway on 01/11/2025.
//

import Foundation

final class MatchedTransaction: Sendable {
  let transaction: Transaction
  let underlyingPrice: Decimal
  let amount: Decimal
  let expenses: Decimal
  let offset: Decimal

  var price: Decimal {
    self.underlyingPrice + (self.offset / self.amount)
  }

  var value: Decimal {
    (self.underlyingPrice * self.amount) + self.offset
  }

  var asset: String {
    self.transaction.asset
  }

  var date: Date {
    self.transaction.date
  }

  init(transaction: Transaction, underlyingPrice: Decimal, amount: Decimal, expenses: Decimal, offset: Decimal) {
    self.transaction = transaction
    self.underlyingPrice = underlyingPrice
    self.amount = amount
    self.expenses = expenses
    self.offset = offset
  }
}

extension MatchedTransaction: CustomStringConvertible {
  var description: String {
    "<\(String(describing: type(of: self))): transaction=\(self.transaction), amount=\(self.amount), underlyingPrice=\(self.underlyingPrice), price=\(self.price), expenses=\(self.expenses), offset=\(self.offset)>"
  }
}
