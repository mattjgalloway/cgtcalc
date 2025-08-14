//
//  AssetProcessorState.swift
//  cgtcalc
//
//  Created by Matt Galloway on 07/06/2020.
//
 Foundation

class AssetProcessorState {
  let asset: String

  var pendingAcquisitions: [TransactionToMatch]
  var pendingDisposals: [TransactionToMatch]
  var assetEvents: [AssetEvent]

  var matchedAcquisitions: [TransactionToMatch] = []
  var processedDisposals: [TransactionToMatch] = []
  var disposalMatches: [DisposalMatch] = []

  var isComplete: Bool { self.pendingDisposals.isEmpty }

  init(asset: String, acquisitions: [TransactionToMatch], disposals: [TransactionToMatch], assetEvents: [AssetEvent]) {
    self.asset = asset
    self.pendingAcquisitions = acquisitions
    self.pendingDisposals = disposals
    self.assetEvents = assetEvents
  }
}
