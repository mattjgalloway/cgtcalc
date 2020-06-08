//
//  Logger.swift
//  cgtcalc
//
//  Created by Matt Galloway on 08/06/2020.
//

public protocol Logger {
  func debug(_ str: String)
  func info(_ str: String)
  func warn(_ str: String)
  func error(_ str: String)
}

public class BasicLogger: Logger {
  public enum Level: Int {
    case Debug = 1
    case Info = 2
    case Warn = 3
    case Error = 4
  }
  public var level: Level = .Info

  public init() {}

  public func debug(_ str: String) {
    if self.level <= .Debug {
      print("[DEBUG] \(str)")
    }
  }

  public func info(_ str: String) {
    if self.level <= .Info {
      print("[INFO] \(str)")
    }
  }

  public func warn(_ str: String) {
    if self.level <= .Warn {
      print("[WARN] \(str)")
    }
  }

  public func error(_ str: String) {
    if self.level <= .Error {
      print("[ERROR] \(str)")
    }
  }
}

extension BasicLogger.Level: Comparable {
  static public func <(lhs: BasicLogger.Level, rhs: BasicLogger.Level) -> Bool {
    return lhs.rawValue < rhs.rawValue
  }
}
