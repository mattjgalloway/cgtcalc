//
//  Logger.swift
//  cgtcalc
//
//  Created by Matt Galloway on 08/06/2020.
//

#if os(Linux)
  import Glibc
#else
  import Darwin
#endif
import Foundation

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

  private class StandardErrorOutputStream: TextOutputStream {
    func write(_ string: String) {
      FileHandle.standardError.write(Data(string.utf8))
    }
  }

  private var outputStream = StandardErrorOutputStream()

  public func debug(_ str: String) {
    if self.level <= .Debug {
      print("[DEBUG] \(str)", to: &self.outputStream)
    }
  }

  public func info(_ str: String) {
    if self.level <= .Info {
      print("[INFO] \(str)", to: &self.outputStream)
    }
  }

  public func warn(_ str: String) {
    if self.level <= .Warn {
      print("[WARN] \(str)", to: &self.outputStream)
    }
  }

  public func error(_ str: String) {
    if self.level <= .Error {
      print("[ERROR] \(str)", to: &self.outputStream)
    }
  }
}

extension BasicLogger.Level: Comparable {
  public static func < (lhs: BasicLogger.Level, rhs: BasicLogger.Level) -> Bool {
    return lhs.rawValue < rhs.rawValue
  }
}
