//
//  AssetResult.swift
//  cgtcalc
//
//  Created by Matt Galloway on 07/06/2020.
//
 Foundation

class AssetResult {
  let asset: String
  let disposalMatches: [DisposalMatch]

  init(asset: String, disposalMatches: [DisposalMatch]) {
    self.asset = asset
    self.disposalMatches = disposalMatches
  }
}

extension AssetResult: CustomStringConvertible {
  var description: String {
    return "<\(String(describing: type(of: self))): asset=\(self.asset), disposalMatches=\(self.disposalMatches)>"
  }
}
