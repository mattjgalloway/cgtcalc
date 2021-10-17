//
//  TaxYear.swift
//  cgtcalc
//
//  Created by Matt Galloway on 08/06/2020.
//

import Foundation

struct TaxYear {
  let year: Int

  var string: String { "\(self.year - 1)/\(self.year)" }

  init(year: Int) {
    self.year = year
  }

  init(containingDate: Date) {
    let calendar = Calendar(identifier: .gregorian)
    let components = calendar.dateComponents([.year, .month, .day], from: containingDate)
    var year = components.year!
    if components.month! > 4 {
      year += 1
    }
    if components.month! == 4, components.day! > 5 {
      year += 1
    }
    self.init(year: year)
  }
}

extension TaxYear: CustomStringConvertible {
  var description: String {
    return self.string
  }
}

extension TaxYear: Comparable {
  static func < (lhs: TaxYear, rhs: TaxYear) -> Bool {
    return lhs.year < rhs.year
  }
}

extension TaxYear: Equatable {
  static func == (lhs: TaxYear, rhs: TaxYear) -> Bool {
    return lhs.year == rhs.year
  }
}

extension TaxYear: Hashable {
  func hash(into hasher: inout Hasher) {
    hasher.combine(self.year)
  }
}

extension TaxYear {
  struct Rates {
    let exemption: Decimal
    let basicRate: Decimal
    let higherRate: Decimal
  }

  static let rates: [TaxYear: Rates] = [
    TaxYear(year: 2014): Rates(exemption: 10900, basicRate: 18, higherRate: 28),
    TaxYear(year: 2015): Rates(exemption: 11000, basicRate: 18, higherRate: 28),
    TaxYear(year: 2016): Rates(exemption: 11100, basicRate: 18, higherRate: 28),
    TaxYear(year: 2017): Rates(exemption: 11100, basicRate: 10, higherRate: 20),
    TaxYear(year: 2018): Rates(exemption: 11300, basicRate: 10, higherRate: 20),
    TaxYear(year: 2019): Rates(exemption: 11700, basicRate: 10, higherRate: 20),
    TaxYear(year: 2020): Rates(exemption: 12000, basicRate: 10, higherRate: 20),
    TaxYear(year: 2021): Rates(exemption: 12300, basicRate: 10, higherRate: 20),
    TaxYear(year: 2022): Rates(exemption: 12300, basicRate: 10, higherRate: 20)
  ]

  var rates: Rates? {
    return TaxYear.rates[self]
  }
}
