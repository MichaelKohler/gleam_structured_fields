/// A name-value pair attached to an `Item` or `InnerList`.
///
/// Parameter names follow the same rules as dictionary keys: they must start
/// with a lowercase letter or `*` and may contain lowercase letters, digits,
/// `_`, `-`, `.`, and `*`. When the value is `Boolean(True)` the `=value`
/// part is omitted during serialization (bare-flag form).
pub type Parameter {
  Parameter(name: String, value: BareItem)
}

/// A member of a Structured Fields List or Dictionary.
///
/// An `Item` carries a single `BareItem` together with zero or more
/// `Parameter`s. An `InnerList` is a parenthesized sequence of `Item`s
/// (no nesting of inner lists is allowed) with its own `Parameter`s.
pub type Element {
  /// A single structured-field item with an optional parameter list.
  Item(value: BareItem, parameters: List(Parameter))
  /// A parenthesized list of items with an optional parameter list.
  InnerList(value: List(Element), parameters: List(Parameter))
}

/// The bare value of a structured-field item, without any parameters.
///
/// The variants map to the seven item types defined in RFC 9651:
///
/// | Variant          | Wire format example   |
/// |------------------|-----------------------|
/// | `BareString`     | `"hello"`             |
/// | `Boolean`        | `?1` / `?0`           |
/// | `ByteSequence`   | `:aGVsbG8=:`          |
/// | `Integer`        | `42`                  |
/// | `Decimal`        | `3.14`                |
/// | `Token`          | `text/html`           |
/// | `DisplayString`  | `%"caf%C3%A9"`        |
pub type BareItem {
  /// A UTF-8 string delimited by double quotes on the wire.
  BareString(String)
  /// A boolean: `?1` for `True`, `?0` for `False`.
  Boolean(Bool)
  /// Arbitrary bytes encoded as standard base64 between colons.
  ByteSequence(BitArray)
  /// A signed integer in the range −999,999,999,999,999 to 999,999,999,999,999.
  Integer(Int)
  /// A decimal with up to three fractional digits.
  Decimal(Float)
  /// An unquoted token made up of a restricted set of ASCII characters.
  Token(String)
  /// A UTF-8 string with percent-encoding for non-printable bytes, prefixed `%"`.
  DisplayString(String)
}
