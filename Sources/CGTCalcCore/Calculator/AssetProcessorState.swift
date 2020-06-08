//
//  AssetProcessorState.swift
//  cgtcalc
//
//  Created by Matt Galloway on 07/06/2020.
//

import Foundation

class AssetProcessorState {
  let asset: String

  var pendingAcquisitions: [SubTransaction]
  var pendingDisposals: [SubTransaction]
  var section104Adjusters: [SubTransaction]

  var matchedAcquisitions: [SubTransaction] = []
  var processedDisposals: [SubTransaction] = []
  var disposalMatches: [DisposalMatch] = []

  var isComplete: Bool {
    get { self.pendingDisposals.isEmpty }
  }

  init(asset: String, acquisitions: [SubTransaction], disposals: [SubTransaction], section104Adjusters: [SubTransaction]) {
    self.asset = asset
    self.pendingAcquisitions = acquisitions
    self.pendingDisposals = disposals
    self.section104Adjusters = section104Adjusters
  }
}
