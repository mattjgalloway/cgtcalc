//
//  ModelCreation.swift
//  CGTCalcCoreTests
//
//  Created by Matt Galloway on 09/06/2020.
//

import Foundation
@testable import CGTCalcCore

struct ModelCreation {

  static func transaction(_ id: Int, _ kind: Transaction.Kind, _ date: String, _ asset: String, _ amount: String, _ price: String, _ expenses: String) -> Transaction {
    return Transaction(id: id, kind: kind, date: DateCreation.date(fromString: date), asset: asset, amount: Decimal(string: amount)!, price: Decimal(string: price)!, expenses: Decimal(string: expenses)!)
  }

  static func assetEvent(_ id: Int, _ kind: AssetEvent.Kind, _ date: String, _ asset: String) -> AssetEvent {
    return AssetEvent(id: id, kind: kind, date: DateCreation.date(fromString: date), asset: asset)
  }

}
