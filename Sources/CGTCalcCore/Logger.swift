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

public protocol Logger: Sendable {
  func debug(_ str: String)
  func info(_ str: String)
  func warn(_ str: String)
  func error(_ str: String)
}

public final class BasicLogger: Logger {
  public enum Level: Int, Sendable {
    case Debug = 1
    case Info = 2
    case Warn = 3
    case Error = 4
  }

  private let level: Level

  public init(level: Level = .Info) {
    self.level = level
  }

  private final class StandardErrorOutputStream: TextOutputStream, Sendable {
    func write(_ string: String) {
      FileHandle.standardError.write(Data(string.utf8))
    }
  }

  private nonisolated(unsafe) var outputStream = StandardErrorOutputStream()

  private func writeToOutput(_ str: String) {
    print(str, to: &self.outputStream)
  }

  public func debug(_ str: String) {
    if self.level <= .Debug {
      self.writeToOutput("[DEBUG] \(str)")
    }
  }

  public func info(_ str: String) {
    if self.level <= .Info {
      self.writeToOutput("[INFO] \(str)")
    }
  }

  public func warn(_ str: String) {
    if self.level <= .Warn {
      self.writeToOutput("[WARN] \(str)")
    }
  }

  public func error(_ str: String) {
    if self.level <= .Error {
      self.writeToOutput("[ERROR] \(str)")
    }
  }
}

extension BasicLogger.Level: Comparable {
  public static func < (lhs: BasicLogger.Level, rhs: BasicLogger.Level) -> Bool {
    return lhs.rawValue < rhs.rawValue
  }
}
