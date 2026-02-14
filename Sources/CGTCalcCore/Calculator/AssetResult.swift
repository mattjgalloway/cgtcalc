//
//  AssetResult.swift
//  cgtcalc
//
//  Created by Matt Galloway on 07/06/2020.
//

import Foundation

final class AssetResult: Sendable {
  let asset: String
  let disposalMatches: [DisposalMatch]
  let holding: Decimal
  let costBasis: Decimal

  init(asset: String, disposalMatches: [DisposalMatch], holding: Decimal, costBasis: Decimal) {
    self.asset = asset
    self.disposalMatches = disposalMatches
    self.holding = holding
    self.costBasis = costBasis
  }
}

extension AssetResult: CustomStringConvertible {
  var description: String {
    "<\(String(describing: type(of: self))): asset=\(self.asset), disposalMatches=\(self.disposalMatches), holding=\(self.holding), costBasis=\(self.costBasis)>"
  }
}
