//
//  TaxMethods.swift
//  cgtcalc
//
//  Created by Matt Galloway on 08/06/2020.
//

import Foundation

class TaxMethods {

  static func roundedGain(_ gain: Decimal) -> Decimal {
    let roundingMode: NSDecimalNumber.RoundingMode
    if gain < 0 {
      roundingMode = .up
    } else {
      roundingMode = .down
    }
    return gain.rounded(to: 0, roundingMode: roundingMode)
  }

}
