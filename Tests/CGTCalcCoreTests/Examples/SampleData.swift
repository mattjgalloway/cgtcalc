//
//  DisposalTests.swift
//  CGTCalcCoreTests
//
//  Created by Matt Galloway on 09/06/2020.
//

import Foundation
@testable import CGTCalcCore

struct SampleData {
  let name: String
  let transactions: [Transaction]
  let assetEvents: [AssetEvent]
  let gains: [TaxYear:Decimal]
  let shouldThrow: Bool

  static let samples: [SampleData] = [
    SampleData(
      name: "BasicSingleAsset",
      transactions: [
        ModelCreation.transaction(1, .Sell, "28/11/2019", "Foo", "2234.0432", "4.6702", "12.5"),
        ModelCreation.transaction(2, .Buy, "28/08/2018", "Foo", "812.9", "4.1565", "12.5"),
        ModelCreation.transaction(3, .Buy, "01/03/2018", "Foo", "1421.1432", "3.6093", "2"),
      ],
      assetEvents: [],
      gains: [
        TaxYear(year: 2020): Decimal(string: "1898")!,
      ],
      shouldThrow: false
    ),
  ]
}
