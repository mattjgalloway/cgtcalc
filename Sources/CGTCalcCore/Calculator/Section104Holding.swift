//
//  Section104Holding.swift
//  cgtcalc
//
//  Created by Matt Galloway on 08/06/2020.
//

import Foundation

// TODO: Change Section104Holding so that it takes list of acquisitions, disposals and split/unsplit asset events.
// TODO: Then a Section 104 disposal match should be changed to have an amount and acquisitions list rather than the cost basis. Cost basis is then calculated from the acquisition events.

class Section104Holding {
  private(set) var state = State(amount: Decimal.zero, cost: 0.0)
  private let logger: Logger

  struct State {
    private(set) var amount: Decimal
    private(set) var cost: Decimal
    var costBasis: Decimal {
      if self.amount.isZero {
        return 0
      }
      return self.cost / self.amount
    }

    fileprivate mutating func add(amount: Decimal, cost: Decimal) {
      self.amount += amount
      self.cost += cost
    }

    fileprivate mutating func remove(amount: Decimal) {
      let costBasis = self.costBasis
      self.amount -= amount
      self.cost -= amount * costBasis
      if self.amount.isZero {
        self.cost = 0
      }
    }

    fileprivate mutating func multiplyAmount(by: Decimal) {
      self.amount *= by
    }

    fileprivate mutating func divideAmount(by: Decimal) {
      self.amount /= by
    }
  }

  init(logger: Logger) {
    self.logger = logger
  }

  func process(acquisition: TransactionToMatch) {
    self.logger.debug("Section 104 +++: \(acquisition)")
    self.state.add(amount: acquisition.amount, cost: acquisition.value + acquisition.expenses)
    self.logger.debug("  New state: \(self.state)")
  }

  func process(disposal: TransactionToMatch) throws -> DisposalMatch {
    self.logger.debug("Section 104 ---: \(disposal)")

    guard self.state.amount >= disposal.amount else {
      throw CalculatorError.InvalidData("Disposing of more than is currently held")
    }

    let disposalMatch = DisposalMatch(
      kind: .Section104(self.state.amount, self.state.costBasis),
      disposal: disposal,
      restructureMultiplier: Decimal(1))

    self.state.remove(amount: disposal.amount)
    self.logger.debug("  New state: \(self.state)")

    return disposalMatch
  }

  func process(assetEvent: AssetEvent) {
    self.logger.debug("Section 104 ===: \(assetEvent)")

    switch assetEvent.kind {
    case .Split(let multiplier):
      self.state.multiplyAmount(by: multiplier)
      self.logger.debug("  Rebasing by mutliplying holding by \(multiplier)")
      self.logger.debug("  New state: \(self.state)")
    case .Unsplit(let multiplier):
      self.state.divideAmount(by: multiplier)
      self.logger.debug("  Rebasing by dividing holding by \(multiplier)")
      self.logger.debug("  New state: \(self.state)")
    case .CapitalReturn(_, _), .Dividend:
      self.logger.debug("  Nothing to do for this asset event.")
    }
  }
}

extension Section104Holding.State: CustomStringConvertible {
  var description: String {
    return "<\(String(describing: type(of: self))): amount=\(self.amount), cost=\(self.cost), costBasis=\(self.costBasis)>"
  }
}
