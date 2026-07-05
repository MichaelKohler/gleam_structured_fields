import gleam/bit_array
import gleam/float
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import structured_fields/types.{
  type BareItem, type Element, type Parameter, BareString, Boolean, ByteSequence,
  Decimal, DisplayString, InnerList, Integer, Item, Parameter, Token,
}

/// Serializes a Structured Fields List to a header string (RFC 9651 §4.1.1).
///
/// Members are joined with `", "`. An empty list produces an empty string.
///
/// Example:
///
/// ```gleam
/// serialize_list([Item(Token("a"), []), Item(Integer(1), [])])
/// // -> "a, 1"
/// ```
pub fn serialize_list(value: List(Element)) -> String {
  value
  |> list.map(serialize_element)
  |> string.join(", ")
}

/// Serializes a Structured Fields Dictionary to a header string (RFC 9651 §4.1.2).
///
/// Entries are joined with `", "`. When a value is `Item(Boolean(True), params)`
/// the `=value` part is omitted (bare-flag shorthand). An empty list produces
/// an empty string.
///
/// Example:
///
/// ```gleam
/// serialize_dictionary([#("a", Item(Boolean(True), [])), #("b", Item(Integer(2), []))])
/// // -> "a, b=2"
/// ```
pub fn serialize_dictionary(pairs: List(#(String, Element))) -> String {
  pairs
  |> list.map(fn(pair) {
    let #(key, element) = pair
    case element {
      Item(Boolean(True), params) -> key <> serialize_parameters(params)
      _ -> key <> "=" <> serialize_element(element)
    }
  })
  |> string.join(", ")
}

/// Serializes a single Structured Fields Item or InnerList to a string
/// (RFC 9651 §4.1.3).
///
/// The bare item value is serialized first, followed by any parameters.
/// For an `InnerList` the members are space-separated and wrapped in
/// parentheses.
///
/// Example:
///
/// ```gleam
/// serialize_item(Item(BareString("hello"), [Parameter("charset", Token("utf-8"))]))
/// // -> "\"hello\";charset=utf-8"
/// ```
pub fn serialize_item(value: Element) -> String {
  case value {
    Item(bare_item, params) ->
      serialize_bare_item(bare_item) <> serialize_parameters(params)
    InnerList(items, params) -> serialize_inner_list(items, params)
  }
}

/// Serializes a parameter list to its wire representation (RFC 9651 §4.1.3.2).
///
/// Each parameter is prefixed with `;`. When the value is `Boolean(True)` the
/// `=value` part is omitted. An empty list produces an empty string.
///
/// Example:
///
/// ```gleam
/// serialize_parameters([Parameter("q", Decimal(0.5)), Parameter("ext", Boolean(True))])
/// // -> ";q=0.5;ext"
/// ```
pub fn serialize_parameters(params: List(Parameter)) -> String {
  params
  |> list.map(fn(param) {
    let Parameter(name, value) = param
    case value {
      Boolean(True) -> ";" <> name
      _ -> ";" <> name <> "=" <> serialize_bare_item(value)
    }
  })
  |> string.join("")
}

fn serialize_element(element: Element) -> String {
  case element {
    Item(_, _) -> serialize_item(element)
    InnerList(items, params) -> serialize_inner_list(items, params)
  }
}

fn serialize_inner_list(
  items: List(Element),
  params: List(Parameter),
) -> String {
  let members =
    items
    |> list.map(serialize_item)
    |> string.join(" ")
  "(" <> members <> ")" <> serialize_parameters(params)
}

fn serialize_bare_item(item: BareItem) -> String {
  case item {
    Integer(n) -> int.to_string(n)
    Decimal(f) -> serialize_decimal(f)
    BareString(s) -> serialize_string(s)
    Token(t) -> t
    ByteSequence(bits) -> ":" <> bit_array.base64_encode(bits, True) <> ":"
    Boolean(True) -> "?1"
    Boolean(False) -> "?0"
    DisplayString(s) -> "%\"" <> serialize_display_string(s) <> "\""
  }
}

fn serialize_decimal(f: Float) -> String {
  let sign = case f <. 0.0 {
    True -> "-"
    False -> ""
  }
  let abs_f = float.absolute_value(f)
  let total = float.round(abs_f *. 1000.0)
  let int_part = total / 1000
  let frac_part = total % 1000
  let frac_str =
    int.to_string(frac_part)
    |> string.pad_start(3, "0")
    |> trim_trailing_zeros
  sign <> int.to_string(int_part) <> "." <> frac_str
}

fn trim_trailing_zeros(s: String) -> String {
  case string.ends_with(s, "0") && string.length(s) > 1 {
    True -> trim_trailing_zeros(string.drop_end(s, 1))
    False -> s
  }
}

fn serialize_string(s: String) -> String {
  let escaped =
    s
    |> string.replace("\\", "\\\\")
    |> string.replace("\"", "\\\"")
  "\"" <> escaped <> "\""
}

fn serialize_display_string(s: String) -> String {
  s
  |> bit_array.from_string
  |> encode_display_string_bytes
}

fn encode_display_string_bytes(bits: BitArray) -> String {
  do_encode_display_string_bytes(bits, [])
  |> list.reverse
  |> string.concat
}

fn do_encode_display_string_bytes(
  bits: BitArray,
  acc: List(String),
) -> List(String) {
  case bits {
    <<>> -> acc
    <<byte, rest:bytes>> -> {
      let chunk = case
        byte >= 0x20 && byte <= 0x7e && byte != 0x22 && byte != 0x25
      {
        True -> bit_array.to_string(<<byte>>) |> result.unwrap("")
        False -> "%" <> to_hex_char(byte / 16) <> to_hex_char(byte % 16)
      }
      do_encode_display_string_bytes(rest, [chunk, ..acc])
    }
    _ -> acc
  }
}

fn to_hex_char(n: Int) -> String {
  case n {
    0 -> "0"
    1 -> "1"
    2 -> "2"
    3 -> "3"
    4 -> "4"
    5 -> "5"
    6 -> "6"
    7 -> "7"
    8 -> "8"
    9 -> "9"
    10 -> "a"
    11 -> "b"
    12 -> "c"
    13 -> "d"
    14 -> "e"
    15 -> "f"
    _ -> "?"
  }
}
