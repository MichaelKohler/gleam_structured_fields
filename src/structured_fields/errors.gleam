pub type ParseError {
  CommaExpectedError(current_position: Int)
  InvalidBoolean(current_position: Int)
  InvalidStringInput(current_position: Int)
  TrailingCommaError(current_position: Int)
  UnrecognizedItemType(current_position: Int)
  WrongDateFormat(current_position: Int)
  WrongDecimalOrIntegerInput(current_position: Int)
}
