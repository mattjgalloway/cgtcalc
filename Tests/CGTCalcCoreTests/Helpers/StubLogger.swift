//
//  StubLogger.swift
//  CGTCalcCoreTests
//
//  Created by Matt Galloway on 09/06/2020.
//

import CGTCalcCore

final class StubLogger: Logger {
  func debug(_ str: String) {}
  func info(_ str: String) {}
  func warn(_ str: String) {}
  func error(_ str: String) {}
}
