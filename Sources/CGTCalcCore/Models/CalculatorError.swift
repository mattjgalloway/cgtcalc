//
//  CalculatorError.swift
//  cgtcalc
//
//  Created by Matt Galloway on 07/06/2020.
//

enum CalculatorError: Error, Sendable {
  case InvalidData(String)
  case TransactionDateNotSupported
  case InternalError(String)
  case Incomplete
}
