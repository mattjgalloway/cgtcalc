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
  public let transactions: [Transaction]
  public let assetEvents: [AssetEvent]

  public init(transactions: [Transaction], assetEvents: [AssetEvent]) {
    self.transactions = transactions
    self.assetEvents = assetEvents
  }
}

public class DefaultParser {
  private let dateFormatter: DateFormatter

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
        guard rowData.count > 0, rowData.first != "#" else {
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
    let strippedData = data.trimmingCharacters(in: .whitespaces)
    let splitData = strippedData.components(separatedBy: .whitespaces).filter { $0.count > 0 }

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

    return Transaction(kind: kind, date: date, asset: asset, amount: amount, price: price, expenses: expenses)
  }

  public func assetEvent(fromData data: Substring) throws -> AssetEvent? {
    let splitData = data.components(separatedBy: .whitespaces)

    switch splitData[0] {
    case "DIVIDEND":
      return try self.parseDividendAssetEvent(fromData: splitData)
    case "CAPRETURN":
      return try self.parseCapitalReturnAssetEvent(fromData: splitData)
    case "SPLIT":
      return try self.parseSplitAssetEvent(fromData: splitData)
    case "UNSPLIT":
      return try self.parseUnsplitAssetEvent(fromData: splitData)
    default:
      return nil
    }
  }

  private func parseDividendAssetEvent(fromData data: [String]) throws -> AssetEvent {
    guard data.count == 5 else {
      throw ParserError.IncorrectNumberOfFields(data.joined(separator: " "))
    }

    guard let date = dateFormatter.date(from: data[1]) else {
      throw ParserError.InvalidDate(data.joined(separator: " "))
    }

    let asset = data[2]

    guard let amount = Decimal(string: data[3]) else {
      throw ParserError.InvalidValue(data.joined(separator: " "))
    }

    guard let value = Decimal(string: data[4]) else {
      throw ParserError.InvalidValue(data.joined(separator: " "))
    }

    let kind = AssetEvent.Kind.Dividend(amount, value)
    return AssetEvent(kind: kind, date: date, asset: asset)
  }

  private func parseCapitalReturnAssetEvent(fromData data: [String]) throws -> AssetEvent {
    guard data.count == 5 else {
      throw ParserError.IncorrectNumberOfFields(data.joined(separator: " "))
    }

    guard let date = dateFormatter.date(from: data[1]) else {
      throw ParserError.InvalidDate(data.joined(separator: " "))
    }

    let asset = data[2]

    guard let amount = Decimal(string: data[3]) else {
      throw ParserError.InvalidValue(data.joined(separator: " "))
    }

    guard let value = Decimal(string: data[4]) else {
      throw ParserError.InvalidValue(data.joined(separator: " "))
    }

    let kind = AssetEvent.Kind.CapitalReturn(amount, value)
    return AssetEvent(kind: kind, date: date, asset: asset)
  }

  private func parseSplitAssetEvent(fromData data: [String]) throws -> AssetEvent {
    guard data.count == 4 else {
      throw ParserError.IncorrectNumberOfFields(data.joined(separator: " "))
    }

    guard let date = dateFormatter.date(from: data[1]) else {
      throw ParserError.InvalidDate(data.joined(separator: " "))
    }

    let asset = data[2]

    guard let multiplier = Decimal(string: data[3]) else {
      throw ParserError.InvalidValue(data.joined(separator: " "))
    }

    let kind = AssetEvent.Kind.Split(multiplier)
    return AssetEvent(kind: kind, date: date, asset: asset)
  }

  private func parseUnsplitAssetEvent(fromData data: [String]) throws -> AssetEvent {
    guard data.count == 4 else {
      throw ParserError.IncorrectNumberOfFields(data.joined(separator: " "))
    }

    guard let date = dateFormatter.date(from: data[1]) else {
      throw ParserError.InvalidDate(data.joined(separator: " "))
    }

    let asset = data[2]

    guard let multiplier = Decimal(string: data[3]) else {
      throw ParserError.InvalidValue(data.joined(separator: " "))
    }

    let kind = AssetEvent.Kind.Unsplit(multiplier)
    return AssetEvent(kind: kind, date: date, asset: asset)
  }
}
