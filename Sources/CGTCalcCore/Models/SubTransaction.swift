//
//  SubTransaction.swift
//  cgtcalc
//
//  Created by Matt Galloway on 07/06/2020.
//

import Foundation

class SubTransaction {
  let transaction: Transaction
  private(set) var amount: Decimal
  private(set) var price: Decimal
  private(set) var expenses: Decimal

  var asset: String {
    return self.transaction.asset
  }

  var date: Date {
    return self.transaction.date
  }

  init(transaction: Transaction) {
    self.transaction = transaction
    self.amount = transaction.amount
    self.price = transaction.price
    self.expenses = transaction.expenses
  }

  func split(withAmount amount: Decimal) throws -> SubTransaction {
    guard amount <= self.amount else {
      throw CalculatorError.InternalError("Tried to split calculator transaction by more than its amount")
    }

    let remainder = SubTransaction(transaction: self.transaction)
    remainder.amount = amount
    remainder.expenses = self.expenses * amount / self.amount

    self.amount -= amount
    self.expenses = self.expenses - remainder.expenses

    return remainder
  }
}

extension SubTransaction: CustomStringConvertible {
  var description: String {
    return "<\(String(describing: type(of: self))): transaction=\(self.transaction), amount=\(self.amount), price=\(self.price), expenses=\(self.expenses)>"
  }
}
