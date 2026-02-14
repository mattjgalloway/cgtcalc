//
//  MatchingProcessor.swift
//  cgtcalc
//
//  Created by Matt Galloway on 07/06/2020.
//

import Foundation

final class MatchingProcessor {
  private let state: AssetProcessorState
  private let logger: Logger
  private var matchCount: Int = 0

  private enum Kind {
    case SameDay
    case BedAndBreakfast
  }

  required init(state: AssetProcessorState, logger: Logger) {
    self.state = state
    self.logger = logger
  }

  func process() throws {
    self.logger.info("Begin matching processor.")

    try self.process(kind: .SameDay)
    try self.process(kind: .BedAndBreakfast)

    self.logger
      .info(
        "Finished matching processor. Matched \(self.matchCount) and there are \(self.state.pendingDisposals.count) disposals left.")
  }

  private func process(kind: Kind) throws {
    var acquisitionIndex = self.state.pendingAcquisitions.startIndex
    var disposalIndex = self.state.pendingDisposals.startIndex
    while acquisitionIndex < self.state.pendingAcquisitions.endIndex,
          disposalIndex < self.state.pendingDisposals.endIndex
    {
      let acquisition = self.state.pendingAcquisitions[acquisitionIndex]
      let disposal = self.state.pendingDisposals[disposalIndex]

      let restructureMultiplier: Decimal
      switch kind {
      case .SameDay:
        if acquisition.date < disposal.date {
          acquisitionIndex += 1
          continue
        } else if disposal.date < acquisition.date {
          disposalIndex += 1
          continue
        }
        restructureMultiplier = Decimal(1)
      case .BedAndBreakfast:
        if acquisition.date < disposal.date {
          acquisitionIndex += 1
          continue
        } else if disposal.date.addingTimeInterval(60 * 60 * 24 * 30) < acquisition.date {
          disposalIndex += 1
          continue
        }

        var currentMultiplier = Decimal(1)
        self.state.assetEvents
          .filter { $0.date > disposal.date && $0.date <= acquisition.date }
          .forEach { assetEvent in
            switch assetEvent.kind {
            case .Split(let m):
              currentMultiplier *= m
            case .Unsplit(let m):
              currentMultiplier /= m
            case .CapitalReturn(_, _), .Dividend:
              break
            }
          }
        restructureMultiplier = currentMultiplier
      }

      // If disposal is too big we split it up
      if disposal.amount * restructureMultiplier > acquisition.amount {
        let splitDisposal = try disposal.split(withAmount: acquisition.amount / restructureMultiplier)
        self.state.pendingDisposals.insert(splitDisposal, at: disposalIndex + 1)
      }

      // If the acquisition is too big we split it up
      if acquisition.amount > disposal.amount * restructureMultiplier {
        let splitAcquisition = try acquisition.split(withAmount: disposal.amount * restructureMultiplier)
        self.state.pendingAcquisitions.insert(splitAcquisition, at: acquisitionIndex + 1)
      }

      let disposalMatch = switch kind {
      case .SameDay:
        DisposalMatch(
          kind: .SameDay(acquisition.createMatchedTransaction()),
          disposal: disposal.createMatchedTransaction(),
          restructureMultiplier: restructureMultiplier)
      case .BedAndBreakfast:
        DisposalMatch(
          kind: .BedAndBreakfast(acquisition.createMatchedTransaction()),
          disposal: disposal.createMatchedTransaction(),
          restructureMultiplier: restructureMultiplier)
      }

      self.logger.info("Matched \(disposal) against \(acquisition).")

      // Now the disposal and acquisition will have the same amount
      self.state.pendingAcquisitions.remove(at: acquisitionIndex)
      self.state.matchedAcquisitions.append(acquisition)
      self.state.pendingDisposals.remove(at: disposalIndex)
      self.state.processedDisposals.append(disposal)
      self.state.disposalMatches.append(disposalMatch)

      // No need to increment the indices because we've removed those elements

      self.matchCount += 1
    }
  }
}
