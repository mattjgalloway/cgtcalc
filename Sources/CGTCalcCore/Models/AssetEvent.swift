//
//  AssetEvent.swift
//  CGTCalcCore
//
//  Created by Matt Galloway on 12/06/2020.
//

import Foundation

public class AssetEvent {
  public enum Kind: Equatable {
    /**
     * Capital return.
     * This is also known as "equalisation". It is a part of a dividend that is not regarded as income. It lowers the cost basis for the shares.
     * First parameter is the amount of shares. Second parameter is the £ value.
     */
    case CapitalReturn(Decimal, Decimal)

    /**
     * Dividend.
     * An income event. Used in capital gains tax purposes only for accumulation share classes where a dividend raises the cost basis for the shares.
     * First parameter is the amount of shares. Second parameter is the £ value.
     */
    case Dividend(Decimal, Decimal)

    /**
     * Stock split.
     * When a stock splits, e.g. every 1 share is replaced with 4 share.
     * Parameter is the ratio of the split. e.g. 4 in the example above.
     */
    case Split(Decimal)

    /**
     * Stock unsplit.
     * When a stock does the oposite of a split, e.g. every 4 shares are replaced with 1 share.
     * Parameter is the ratio of the unsplit. e.g. 4 in the example above.
     */
    case Unsplit(Decimal)

    // Allowing for stripped enum (without the associated values)
    var `case`: Case {
      switch self {
      case .CapitalReturn:
        return .CapitalReturn
      case .Dividend:
        return .Dividend
      case .Split:
        return .Split
      case .Unsplit:
        return .Unsplit
      }
    }

    enum Case {
      case CapitalReturn
      case Dividend
      case Split
      case Unsplit
    }
  }

  let kind: Kind
  let date: Date
  let asset: String

  public init(kind: Kind, date: Date, asset: String) {
    self.kind = kind
    self.date = date
    self.asset = asset
  }

  public static func grouped(_ events: [AssetEvent]) throws -> AssetEvent {
    guard let firstEvent = events.first else {
      throw CalculatorError.InternalError("Cannot group 0 asset events")
    }
    guard events.count > 1 else {
      return events[0]
    }
    guard Set(events.map(\.kind.case)).count == 1 else {
      throw CalculatorError.InternalError("Cannot group asset events that don't have the same kind")
    }
    guard Set(events.map(\.date)).count == 1 else {
      throw CalculatorError.InternalError("Cannot group asset events that don't have the same date")
    }
    guard Set(events.map(\.asset)).count == 1 else {
      throw CalculatorError.InternalError("Cannot group asset events that don't have the same asset")
    }

    switch firstEvent.kind.case {
    case .CapitalReturn:
      var runningAmount = Decimal.zero
      var runningValue = Decimal.zero
      for event in events {
        if case .CapitalReturn(let amount, let value) = event.kind {
          runningAmount += amount
          runningValue += value
        }
      }
      return AssetEvent(
        kind: .CapitalReturn(runningAmount, runningValue),
        date: firstEvent.date,
        asset: firstEvent.asset)

    case .Dividend:
      var runningAmount = Decimal.zero
      var runningValue = Decimal.zero
      for event in events {
        if case .Dividend(let amount, let value) = event.kind {
          runningAmount += amount
          runningValue += value
        }
      }
      return AssetEvent(kind: .Dividend(runningAmount, runningValue), date: firstEvent.date, asset: firstEvent.asset)

    case .Split:
      var runningAmount = Decimal(1)
      for event in events {
        if case .Split(let amount) = event.kind {
          runningAmount *= amount
        }
      }
      return AssetEvent(kind: .Split(runningAmount), date: firstEvent.date, asset: firstEvent.asset)

    case .Unsplit:
      var runningAmount = Decimal(1)
      for event in events {
        if case .Unsplit(let amount) = event.kind {
          runningAmount *= amount
        }
      }
      return AssetEvent(kind: .Unsplit(runningAmount), date: firstEvent.date, asset: firstEvent.asset)
    }
  }
}

extension AssetEvent: CustomStringConvertible {
  public var description: String {
    return "<\(String(describing: type(of: self))): kind=\(self.kind), date=\(self.date), asset=\(self.asset)>"
  }
}

extension AssetEvent: Equatable {
  public static func == (lhs: AssetEvent, rhs: AssetEvent) -> Bool {
    return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
  }
}

extension AssetEvent: Hashable {
  public func hash(into hasher: inout Hasher) {
    return hasher.combine(ObjectIdentifier(self))
  }
}
