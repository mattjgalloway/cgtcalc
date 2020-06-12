//
//  Transaction.swift
//  cgtcalc
//
//  Created by Matt Galloway on 06/06/2020.
//

import Foundation

public class Transaction {
  typealias Id = Int

  enum Kind {
    case Buy
    case Sell
  }

  let id: Id
  let kind: Kind
  let date: Date
  let asset: String
  let amount: Decimal
  let price: Decimal
  let expenses: Decimal

  init(id: Id, kind: Kind, date: Date, asset: String, amount: Decimal, price: Decimal, expenses: Decimal) {
    self.id = id
    self.kind = kind
    self.date = date
    self.asset = asset
    self.amount = amount
    self.price = price
    self.expenses = expenses
  }
}

extension Transaction: CustomStringConvertible {
  public var description: String {
    return "<\(String(describing: type(of: self))): id=\(self.id), kind=\(self.kind), date=\(self.date), asset=\(asset), amount=\(self.amount), price=\(self.price), expenses=\(self.expenses)>"
  }
}
