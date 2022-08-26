//
//  PDFPresenter.swift
//  CGTCalcCore
//
//  Created by Matt Galloway on 07/05/2022.
//

import Foundation
import PDFKit

public class PDFPresenter: Presenter {
  private let result: CalculatorResult

  public required init(result: CalculatorResult) {
    self.result = result
  }

  public func process() throws -> PresenterResult {
    return .data(Data())
  }
}
