//
//  DisposalMatch.swift
//  cgtcalc
//
//  Created by Matt Galloway on 08/06/2020.
//

import Foundation

class DisposalMatch {
  let kind: Kind
  let disposal: TransactionToMatch
  let restructureMultiplier: Decimal

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
    /**
     * Same day match.
     * Parameter is the buy transaction that this disposal was matched against.
     */
    case SameDay(TransactionToMatch)

    /**
     * Bed-and-breakfast match (buy within 30 days of a sale).
     * Parameter is the buy transaction that this disposal was matched against.
     */
    case BedAndBreakfast(TransactionToMatch)

    /**
     * Section 104 holding match (pool of shares not matched on any other rule).
     * First parameter is the amount of holding, second parameter is the cost basis.
     */
    case Section104(Decimal, Decimal)
  }

  init(kind: Kind, disposal: TransactionToMatch, restructureMultiplier: Decimal) {
    self.kind = kind
    self.disposal = disposal
    self.restructureMultiplier = restructureMultiplier
  }

  var gain: Decimal {
    switch self.kind {
    case .SameDay(let acquisition), .BedAndBreakfast(let acquisition):
      let disposalProceeds = self.disposal.value - self.disposal.expenses
      let acquisitionProceeds = acquisition.value + acquisition.expenses
      return disposalProceeds - acquisitionProceeds
    case .Section104(_, let costBasis):
      let disposalProceeds = self.disposal.value - self.disposal.expenses
      let acquisitionProceeds = self.disposal.amount * costBasis
      return disposalProceeds - acquisitionProceeds
    }
  }

  var allowableCosts: Decimal {
    // TODO: Should probably make the DisposalMatch hold the costs and the gain is calculated from the costs, not the other way around
    return self.disposal.value - self.gain
  }
}

extension DisposalMatch: CustomStringConvertible {
  var description: String {
    return "<\(String(describing: type(of: self))): kind=\(self.kind), asset=\(self.asset), date=\(self.date), taxYear=\(self.taxYear), disposal=\(self.disposal), gain=\(self.gain), restructureMultiplier=\(self.restructureMultiplier)>"
  }
}
