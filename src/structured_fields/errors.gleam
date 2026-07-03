/// Errors that can occur while parsing a Structured Fields header value.
///
/// Every variant that carries a position reports the byte offset inside the
/// input string at which the problem was detected, which is useful for
/// constructing diagnostic messages.
pub type ParseError {
  /// A comma was expected between two list or dictionary members but was not
  /// found. The position points to the unexpected character.
  CommaExpectedError(current_position: Int)

  /// The character following `?` was neither `0` nor `1`.
  InvalidBoolean(current_position: Int)

  /// The content between the two `:` delimiters is not valid base64, or the
  /// closing `:` is missing.
  InvalidByteSequence(current_position: Int)

  /// The display string (`%"..."`) is malformed: a percent-escape is
  /// incomplete, an escaped byte is outside the printable ASCII range, or the
  /// closing `"` is missing.
  InvalidDisplayString(current_position: Int)

  /// A dictionary key or parameter name is absent or starts with a character
  /// that is not a lowercase letter or `*`.
  InvalidParameterKey(current_position: Int)

  /// A quoted string contains a character outside the printable ASCII range
  /// (0x20–0x7E), an invalid escape sequence, or the closing `"` is missing.
  InvalidStringInput(current_position: Int)

  /// The input contains at least one byte with a code point above 127 (i.e.
  /// non-ASCII). Structured Fields headers must be 7-bit ASCII.
  NonAsciiInput

  /// A comma was found after the last list or dictionary member with no
  /// following member. The position points past the comma.
  TrailingCommaError(current_position: Int)

  /// An inner list opened with `(` was never closed with `)`.
  UnclosedInnerList(current_position: Int)

  /// The first character of a bare item did not match any of the known
  /// item-type prefixes.
  UnrecognizedItemType(current_position: Int)

  /// A date value (prefixed `@`) contained a decimal point; dates must be
  /// integers.
  WrongDateFormat(current_position: Int)

  /// A number could not be parsed as a valid integer or decimal, for example
  /// because it has more than 15 significant digits, more than three fractional
  /// digits, or ends with a decimal point.
  WrongDecimalOrIntegerInput(current_position: Int)
}
