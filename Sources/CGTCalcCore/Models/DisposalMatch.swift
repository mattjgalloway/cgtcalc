//
//  DisposalMatch.swift
//  cgtcalc
//
//  Created by Matt Galloway on 08/06/2020.
//

import Foundation

class DisposalMatch {
  let kind: Kind
  let disposal: SubTransaction

  var asset: String {
    return self.disposal.asset
  }

  var date: Date {
    return self.disposal.date
  }

  var taxYear: TaxYear {
    return TaxYear(containingDate: self.disposal.date)
  }

  enum Kind {
    case SameDay(SubTransaction)
    case BedAndBreakfast(SubTransaction)
    case Section104(Decimal, Decimal)
  }

  init(kind: Kind, disposal: SubTransaction) {
    self.kind = kind
    self.disposal = disposal
  }

  var gain: Decimal {
    switch self.kind {
    case .SameDay(let acquisition), .BedAndBreakfast(let acquisition):
      let disposalProceeds = self.disposal.amount * self.disposal.price - self.disposal.expenses
      let acquisitionProceeds = acquisition.amount * acquisition.price + acquisition.expenses
      return TaxMethods.roundedGain(disposalProceeds - acquisitionProceeds)
    case .Section104(_, let costBasis):
      let disposalProceeds = self.disposal.amount * self.disposal.price - self.disposal.expenses
      let acquisitionProceeds = self.disposal.amount * costBasis
      return TaxMethods.roundedGain(disposalProceeds - acquisitionProceeds)
    }
  }
}

extension DisposalMatch: CustomStringConvertible {
  var description: String {
    return "<\(String(describing: type(of: self))): kind=\(self.kind), asset=\(self.asset), date=\(self.date), taxYear=\(self.taxYear), disposal=\(self.disposal), gain=\(self.gain)>"
  }
}
