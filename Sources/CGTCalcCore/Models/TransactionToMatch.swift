//
//  TransactionToMatch.swift
//  cgtcalc
//
//  Created by Matt Galloway on 07/06/2020.
//

import Foundation
import Synchronization

final class TransactionToMatch: Sendable {
  let transaction: Transaction
  let underlyingPrice: Decimal

  private struct State {
    var amount: Decimal
    var expenses: Decimal
    var offset: Decimal
  }
  private let state: Mutex<State>

  var amount: Decimal {
    self.state.withLock { $0.amount }
  }

  var expenses: Decimal {
    self.state.withLock { $0.expenses }
  }

  var offset: Decimal {
    self.state.withLock { $0.offset }
  }

  var price: Decimal {
    self.state.withLock {
      self.underlyingPrice + ($0.offset / $0.amount)
    }
  }

  var value: Decimal {
    self.state.withLock {
      (self.underlyingPrice * $0.amount) + $0.offset
    }
  }

  var asset: String {
    self.transaction.asset
  }

  var date: Date {
    self.transaction.date
  }

  convenience init(transaction: Transaction) {
    self.init(transaction: transaction, amount: transaction.amount, expenses: transaction.expenses, offset: Decimal.zero)
  }

  private init(transaction: Transaction, amount: Decimal, expenses: Decimal, offset: Decimal) {
    self.transaction = transaction
    self.underlyingPrice = transaction.price
    self.state = Mutex(State(amount: amount, expenses: expenses, offset: offset))
  }

  func split(withAmount amount: Decimal) throws -> TransactionToMatch {
    let remainder = try self.state.withLock {
      guard amount <= $0.amount else {
        throw CalculatorError.InternalError("Tried to split calculator transaction by more than its amount")
      }

      let remainderAmount = $0.amount - amount
      let remainderExpenses = $0.expenses * remainderAmount / $0.amount
      let remainderOffset = $0.offset * remainderAmount / $0.amount
      let remainder = TransactionToMatch(transaction: self.transaction, amount: remainderAmount, expenses: remainderExpenses, offset: remainderOffset)

      $0.amount = amount
      $0.expenses = $0.expenses - remainderExpenses
      $0.offset = $0.offset - remainderOffset

      return remainder
    }
    return remainder
  }

  func addOffset(amount: Decimal) {
    self.state.withLock {
      $0.offset += amount
    }
  }

  func subtractOffset(amount: Decimal) {
    self.state.withLock {
      $0.offset -= amount
    }
  }
}

extension TransactionToMatch: CustomStringConvertible {
  var description: String {
    return "<\(String(describing: type(of: self))): transaction=\(self.transaction), amount=\(self.amount), underlyingPrice=\(self.underlyingPrice), price=\(self.price), expenses=\(self.expenses), offset=\(self.offset)>"
  }
}
