//
//  TransactionToMatch.swift
//  cgtcalc
//
//  Created by Matt Galloway on 07/06/2020.
//

import Foundation

final class TransactionToMatch {
  let transaction: Transaction
  let underlyingPrice: Decimal

  var amount: Decimal
  var expenses: Decimal
  var offset: Decimal

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

  convenience init(transaction: Transaction) {
    self.init(
      transaction: transaction,
      amount: transaction.amount,
      expenses: transaction.expenses,
      offset: Decimal.zero)
  }

  private init(transaction: Transaction, amount: Decimal, expenses: Decimal, offset: Decimal) {
    self.transaction = transaction
    self.underlyingPrice = transaction.price
    self.amount = amount
    self.expenses = expenses
    self.offset = offset
  }

  func split(withAmount amount: Decimal) throws -> TransactionToMatch {
    guard amount <= self.amount else {
      throw CalculatorError.InternalError("Tried to split calculator transaction by more than its amount")
    }

    let remainderAmount = self.amount - amount
    let remainderExpenses = self.expenses * remainderAmount / self.amount
    let remainderOffset = self.offset * remainderAmount / self.amount
    let remainder = TransactionToMatch(
      transaction: self.transaction,
      amount: remainderAmount,
      expenses: remainderExpenses,
      offset: remainderOffset)

    self.amount = amount
    self.expenses = self.expenses - remainderExpenses
    self.offset = self.offset - remainderOffset

    return remainder
  }

  func addOffset(amount: Decimal) {
    self.offset += amount
  }

  func subtractOffset(amount: Decimal) {
    self.offset -= amount
  }

  func createMatchedTransaction() -> MatchedTransaction {
    MatchedTransaction(
      transaction: self.transaction,
      underlyingPrice: self.underlyingPrice,
      amount: self.amount,
      expenses: self.expenses,
      offset: self.offset)
  }
}

extension TransactionToMatch: CustomStringConvertible {
  var description: String {
    "<\(String(describing: type(of: self))): transaction=\(self.transaction), amount=\(self.amount), underlyingPrice=\(self.underlyingPrice), price=\(self.price), expenses=\(self.expenses), offset=\(self.offset)>"
  }
}
