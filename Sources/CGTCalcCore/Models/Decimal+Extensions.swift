//
//  Decimal+Extensions.swift
//  cgtcalc
//
//  Created by Matt Galloway on 09/06/2020.
//

import Foundation

extension Decimal {
  func rounded(to scale: Int, roundingMode: NSDecimalNumber.RoundingMode = .plain) -> Decimal {
    var input = self
    var result: Decimal = .zero
    NSDecimalRound(&result, &input, scale, roundingMode)
    return result
  }

  var string: String {
    var input = self
    return NSDecimalString(&input, nil)
  }
}
