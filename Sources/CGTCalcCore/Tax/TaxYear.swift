//
//  TaxYear.swift
//  cgtcalc
//
//  Created by Matt Galloway on 08/06/2020.
//

import Foundation

struct TaxYear {
  let year: Int

  var string: String {
    get { "\(year-1)/\(year)" }
  }

  init(year: Int) {
    self.year = year
  }

  init(containingDate: Date) {
    let calendar = Calendar(identifier: .gregorian)
    let components = calendar.dateComponents([.year, .month, .day], from: containingDate)
    guard
      var year = components.year,
      let month = components.month,
      let day = components.day else {
        fatalError("Failed to extract date components when calculating tax year")
    }
    if month > 4 {
      year += 1
    }
    if month == 4 && day > 5 {
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

  static let rates: [TaxYear:Rates] = [
    TaxYear(year: 2015): Rates(exemption: 11000, basicRate: 18, higherRate: 28),
    TaxYear(year: 2016): Rates(exemption: 11100, basicRate: 18, higherRate: 28),
    TaxYear(year: 2017): Rates(exemption: 11100, basicRate: 10, higherRate: 20),
    TaxYear(year: 2018): Rates(exemption: 11300, basicRate: 10, higherRate: 20),
    TaxYear(year: 2019): Rates(exemption: 11700, basicRate: 10, higherRate: 20),
    TaxYear(year: 2020): Rates(exemption: 12000, basicRate: 10, higherRate: 20),
    TaxYear(year: 2021): Rates(exemption: 12300, basicRate: 10, higherRate: 20),
  ]

  var rates: Rates? {
    return TaxYear.rates[self]
  }
}
