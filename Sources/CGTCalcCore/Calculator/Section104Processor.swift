//
//  Section104Processor.swift
//  cgtcalc
//
//  Created by Matt Galloway on 07/06/2020.
//

import Foundation

class Section104Processor {
  private let state: AssetProcessorState
  private let logger: Logger

  required init(state: AssetProcessorState, logger: Logger) {
    self.state = state
    self.logger = logger
  }

  func process() throws {
    self.logger.debug("Section 104: Begin processor")

    let section104Holding = Section104Holding(logger: self.logger)

    var allAcquisitions = (self.state.pendingAcquisitions + self.state.section104Adjusters)
      .sorted { $0.date > $1.date }
    let disposalsIndex = self.state.pendingDisposals.startIndex

    while disposalsIndex < self.state.pendingDisposals.endIndex {
      let disposal = self.state.pendingDisposals[disposalsIndex]
      if let acquisition = allAcquisitions.popLast() {
        if acquisition.date <= disposal.date {
          section104Holding.process(acquisition: acquisition)
          continue
        }
      }

      let disposalMatch = try section104Holding.process(disposal: disposal)
      self.state.processedDisposals.append(disposal)
      self.state.pendingDisposals.remove(at: disposalsIndex)
      self.state.disposalMatches.append(disposalMatch)
    }

    self.logger.debug("Section 104: Finished processor. There are \(self.state.pendingDisposals.count) disposals left.")
  }
}
