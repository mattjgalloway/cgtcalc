//
//  TaxMethods.swift
//  cgtcalc
//
//  Created by Matt Galloway on 08/06/2020.
//

import Foundation

class TaxMethods {
  static func roundedGain(_ gain: Decimal) -> Decimal {
    gain.rounded(to: 0, roundingMode: .down)
  }
}
