//
//  Presenter.swift
//  CGTCalcCore
//
//  Created by Matt Galloway on 07/05/2022.
//

import Foundation

public enum PresenterResult {
  case data(Data)
  case string(String)
}

public init Presenter {
  init(result: CalculatorResult)
  func process() throws -> PresenterResult
}
