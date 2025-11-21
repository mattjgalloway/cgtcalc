//
//  Presenter.swift
//  CGTCalcCore
//
//  Created by Matt Galloway on 07/05/2022.
//

import Foundation

public enum PresenterResult: Sendable {
  case data(Data)
  case string(String)
}

public protocol Presenter: Sendable {
  init(result: CalculatorResult)
  func process() throws -> PresenterResult
}
