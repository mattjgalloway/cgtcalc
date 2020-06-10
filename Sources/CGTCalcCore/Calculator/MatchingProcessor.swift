//
//  MatchingProcessor.swift
//  cgtcalc
//
//  Created by Matt Galloway on 07/06/2020.
//

import Foundation

class MatchingProcessor {
  enum MatchResult {
    case SkipAcquisition
    case SkipDisposal
    case Match(DisposalMatch)
  }
  typealias Matcher = (SubTransaction, SubTransaction) -> MatchResult

  private let state: AssetProcessorState
  private let logger: Logger
  private let matcher: Matcher
  private var matchCount: Int = 0

  required init(state: AssetProcessorState, logger: Logger, matcher: @escaping Matcher) {
    self.state = state
    self.logger = logger
    self.matcher = matcher
  }

  func process() throws {
    self.logger.debug("Begin matching processor.")

    var acquisitionIndex = self.state.pendingAcquisitions.startIndex
    var disposalIndex = self.state.pendingDisposals.startIndex
    while acquisitionIndex < self.state.pendingAcquisitions.endIndex && disposalIndex < self.state.pendingDisposals.endIndex {
      let acquisition = self.state.pendingAcquisitions[acquisitionIndex]
      let disposal = self.state.pendingDisposals[disposalIndex]

      switch self.matcher(acquisition, disposal) {
      case .SkipAcquisition:
        acquisitionIndex += 1
        continue
      case .SkipDisposal:
        disposalIndex += 1
        continue
      case .Match(let disposalMatch):
        self.state.disposalMatches.append(disposalMatch)
        break
      }

      // If disposal is too big we split it up
      if disposal.amount > acquisition.amount {
        let splitDisposal = try disposal.split(withAmount: acquisition.amount)
        self.state.pendingDisposals.insert(splitDisposal, at: disposalIndex + 1)
      }

      // If the acquisition is too big we split it up
      if acquisition.amount > disposal.amount {
        let splitAcquisition = try acquisition.split(withAmount: disposal.amount)
        self.state.pendingAcquisitions.insert(splitAcquisition, at: acquisitionIndex + 1)
      }

      self.logger.info("Matched \(disposal) against \(acquisition).")

      // Now the disposal and acquisition will have the same amount
      self.state.pendingAcquisitions.remove(at: acquisitionIndex)
      self.state.matchedAcquisitions.append(acquisition)
      self.state.pendingDisposals.remove(at: disposalIndex)
      self.state.processedDisposals.append(disposal)

      // No need to increment the indices because we've removed those elements

      self.matchCount += 1
    }

    self.logger.debug("Finished matching processor. Matched \(self.matchCount) and there are \(self.state.pendingDisposals.count) disposals left.")
  }
}
