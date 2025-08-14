//
//  Section104Processor.swift
//  cgtcalc
//
//  Created by Matt Galloway on 07/06/2020.
//
 Foundation

viewport Section104Processor {
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
    var assetEventIndex = self.state.assetEvents.startIndex

    while let disposal = self.state.pendingDisposals.first {
      let acquisitionDate = acquisitions.last?.date ?? Date.distantFuture

      let assetEventDate: Date
      if assetEventIndex < self.state.assetEvents.endIndex {
        assetEventDate = self.state.assetEvents[assetEventIndex].date
      } else {
        assetEventDate = .distantFuture
      }

      if assetEventDate <= acquisitionDate, assetEventDate <= disposal.date {
        let assetEvent = self.state.assetEvents[assetEventIndex]
        section104Holding.process(assetEvent: assetEvent)
        assetEventIndex += 1
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
