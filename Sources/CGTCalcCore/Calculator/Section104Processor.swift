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

    var acquisitions = self.state.pendingAcquisitions.sorted { $0.date > $1.date }
    var assetEvents = self.state.assetEvents.sorted { $0.date > $1.date }

    while let disposal = self.state.pendingDisposals.first {
      let acquisitionDate: Date
      if let acquisition = acquisitions.last {
        acquisitionDate = acquisition.date
      } else {
        acquisitionDate = Date.distantFuture
      }

      let assetEventDate: Date
      if let assetEvent = assetEvents.last {
        assetEventDate = assetEvent.date
      } else {
        assetEventDate = Date.distantFuture
      }

      if assetEventDate <= acquisitionDate && assetEventDate <= disposal.date {
        if let assetEvent = assetEvents.last {
          try section104Holding.process(assetEvent: assetEvent)
          _ = assetEvents.removeLast()
        }
        continue
      } else if acquisitionDate <= disposal.date {
        if let acquisition = acquisitions.last {
          section104Holding.process(acquisition: acquisition)
          _ = acquisitions.removeLast()
        }
        continue
      }

      let disposalMatch = try section104Holding.process(disposal: disposal)
      self.state.processedDisposals.append(disposal)
      self.state.pendingDisposals.remove(at: self.state.pendingDisposals.startIndex)
      self.state.disposalMatches.append(disposalMatch)
    }

    self.logger.debug("Section 104: Finished processor. There are \(self.state.pendingDisposals.count) disposals left.")
  }
}
