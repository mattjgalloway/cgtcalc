//
//  AssetEvent.swift
//  CGTCalcCore
//
//  Created by Matt Galloway on 12/06/2020.
//

import Foundation

public class AssetEvent {
  typealias Id = Int

  enum Kind: Equatable {
    case CapitalReturn(Decimal, Decimal)
    case Dividend(Decimal, Decimal)
  }

  let id: Id
  let kind: Kind
  let date: Date
  let asset: String

  init(id: Id, kind: Kind, date: Date, asset: String) {
    self.id = id
    self.kind = kind
    self.date = date
    self.asset = asset
  }
}

extension AssetEvent: CustomStringConvertible {
  public var description: String {
    return "<\(String(describing: type(of: self))): id=\(self.id), kind=\(self.kind), date=\(self.date), asset=\(asset)>"
  }
}
