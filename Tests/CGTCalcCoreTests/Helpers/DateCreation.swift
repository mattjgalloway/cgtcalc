//
//  DateCreation.swift
//  CGTCalcCoreTests
//
//  Created by Matt Galloway on 09/06/2020.
//

import Foundation

struct DateCreation {
  private static let dateFormatter: DateFormatter = {
    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
    dateFormatter.dateFormat = "dd/MM/yyyy"
    return dateFormatter
  }()

  static func date(fromString string: String) -> Date {
    return self.dateFormatter.date(from: string)!
  }
}
