//
//  SubTransaction.swift
//  cgtcalc
//
//  Created by Matt Galloway on 07/06/2020.
//

import Foundation

class SubTransaction {
  let transaction: Transaction
  let underlyingPrice: Decimal
  private(set) var amount: Decimal
  private(set) var expenses: Decimal
  private(set) var offset = Decimal.zero

  var price: Decimal {
    return self.underlyingPrice + (self.offset / self.amount)
  }

  var value: Decimal {
    return (self.underlyingPrice * self.amount) + self.offset
  }

  var asset: String {
    return self.transaction.asset
  }

  var date: Date {
    return self.transaction.date
  }

  init(transaction: Transaction) {
    self.transaction = transaction
    self.amount = transaction.amount
    self.underlyingPrice = transaction.price
    self.expenses = transaction.expenses
  }

  func split(withAmount amount: Decimal) throws -> SubTransaction {
    guard amount <= self.amount else {
      throw CalculatorError.InternalError("Tried to split calculator transaction by more than its amount")
    }

    let remainder = SubTransaction(transaction: self.transaction)
    let remainderAmount = self.amount - amount
    remainder.amount = remainderAmount
    remainder.expenses = self.expenses * remainderAmount / self.amount

    self.amount = amount
    self.expenses = self.expenses - remainder.expenses

    return remainder
  }

  func addOffset(amount: Decimal) {
    self.offset += amount
  }

  func subtractOffset(amount: Decimal) {
    self.offset -= amount
  }
}

extension SubTransaction: CustomStringConvertible {
  var description: String {
    return "<\(String(describing: type(of: self))): transaction=\(self.transaction), amount=\(self.amount), underlyingPrice=\(self.underlyingPrice), price=\(self.price), expenses=\(self.expenses), offset=\(self.offset)>"
  }
}
