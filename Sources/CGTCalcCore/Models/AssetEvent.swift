//
//  AssetEvent.swift
//  CGTCalcCore
//
//  Created by Matt Galloway on 12/06/2020.
//

import Foundation

public class AssetEvent {
  enum Kind: Equatable {
    case CapitalReturn(Decimal, Decimal)
    case Dividend(Decimal, Decimal)
    case Split(Decimal)
    case Unsplit(Decimal)
  }

  let kind: Kind
  let date: Date
  let asset: String

  init(kind: Kind, date: Date, asset: String) {
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
