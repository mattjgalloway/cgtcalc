import Foundation

enum UTC {
  static let timeZone = TimeZone(secondsFromGMT: 0)!

  static let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = UTC.timeZone
    return calendar
  }()
}
