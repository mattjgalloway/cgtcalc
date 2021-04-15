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
  }

  let kind: Kind
  let date: Date
  let asset: String

  public init(kind: Kind, date: Date, asset: String) {
    self.kind = kind
    self.date = date
    self.asset = asset
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
