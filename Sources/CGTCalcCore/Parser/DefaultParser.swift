//
//  DefaultParser.swift
//  CGTCalcCore
//
//  Created by Matt Galloway on 09/06/2020.
//

import Foundation

enum ParserError: Error {
  case IncorrectNumberOfFields(String)
  case InvalidKind(String)
  case InvalidDate(String)
  case InvalidAmount(String)
  case InvalidPrice(String)
  case InvalidExpenses(String)
  case InvalidValue(String)
}

public class CalculatorInput {
  let transactions: [Transaction]
  let assetEvents: [AssetEvent]

  init(transactions: [Transaction], assetEvents: [AssetEvent]) {
    self.transactions = transactions
    self.assetEvents = assetEvents
  }
}

public class DefaultParser {
  private let dateFormatter: DateFormatter
  private var nextId: Int = 1

  public init() {
    self.dateFormatter = DateFormatter()
    self.dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    self.dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
    self.dateFormatter.dateFormat = "dd/MM/yyyy"
  }

  public func calculatorInput(fromData data: String) throws -> CalculatorInput {
    var transactions: [Transaction] = []
    var assetEvents: [AssetEvent] = []
    try data
      .split { $0.isNewline }
      .forEach { rowData in
        guard rowData.count > 0 && rowData.first != "#" else {
          return
        }

        if let transaction = try self.transaction(fromData: rowData) {
          transactions.append(transaction)
        } else if let assetEvent = try self.assetEvent(fromData: rowData) {
          assetEvents.append(assetEvent)
        } else {
          throw ParserError.InvalidKind(String(rowData))
        }
      }
    return CalculatorInput(transactions: transactions, assetEvents: assetEvents)
  }

  public func transaction(fromData data: Substring) throws -> Transaction? {
    let splitData = data.components(separatedBy: .whitespaces)

    let kind: Transaction.Kind
    switch splitData[0] {
    case "BUY":
      kind = .Buy
    case "SELL":
      kind = .Sell
    default:
      return nil
    }

    guard splitData.count == 6 else {
      throw ParserError.IncorrectNumberOfFields(String(data))
    }

    guard let date = dateFormatter.date(from: splitData[1]) else {
      throw ParserError.InvalidDate(String(data))
    }

    let asset = splitData[2]

    guard let amount = Decimal(string: splitData[3]) else {
      throw ParserError.InvalidAmount(String(data))
    }

    guard let price = Decimal(string: splitData[4]) else {
      throw ParserError.InvalidPrice(String(data))
    }

    guard let expenses = Decimal(string: splitData[5]) else {
      throw ParserError.InvalidExpenses(String(data))
    }

    let id = self.nextId
    self.nextId += 1

    return Transaction(id: id, kind: kind, date: date, asset: asset, amount: amount, price: price, expenses: expenses)
  }

  public func assetEvent(fromData data: Substring) throws -> AssetEvent? {
    let splitData = data.components(separatedBy: .whitespaces)

    switch splitData[0] {
    case "ADJ":
      // We can't actually set kind here because we need the associated value
      break
    default:
      return nil
    }

    guard splitData.count == 4 else {
      throw ParserError.IncorrectNumberOfFields(String(data))
    }

    guard let date = dateFormatter.date(from: splitData[1]) else {
      throw ParserError.InvalidDate(String(data))
    }

    let asset = splitData[2]

    guard let value = Decimal(string: splitData[3]) else {
      throw ParserError.InvalidValue(String(data))
    }

    let kind: AssetEvent.Kind
    switch splitData[0] {
    case "ADJ":
      kind = .Section104Adjust(value)
    default:
      return nil
    }

    let id = self.nextId
    self.nextId += 1

    return AssetEvent(id: id, kind: kind, date: date, asset: asset)
  }
}
