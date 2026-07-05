import gleam/bit_array
import gleam/bool
import gleam/float
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import structured_fields/errors.{
  type ParseError, CommaExpectedError, InvalidBoolean, InvalidByteSequence,
  InvalidDisplayString, InvalidParameterKey, InvalidStringInput, NonAsciiInput,
  TrailingCommaError, UnclosedInnerList, UnrecognizedItemType, WrongDateFormat,
  WrongDecimalOrIntegerInput,
}
import structured_fields/types.{
  type BareItem, type Element, type Parameter, BareString, Boolean, ByteSequence,
  Decimal, DisplayString, InnerList, Integer, Item, Parameter, Token,
}

type IntegerOrDecimal {
  IsInteger(Int)
  IsDecimal(Float)
}

/// Parses a Structured Fields List header value (RFC 9651 §4.2.1).
///
/// A list is a comma-separated sequence of items and inner lists. Whitespace
/// around commas is ignored. Returns `Ok([])` for an empty string.
///
/// Example:
///
/// ```gleam
/// parse_list("sugar, tea, rum")
/// // -> Ok([
/// //   Item(Token("sugar"), []),
/// //   Item(Token("tea"), []),
/// //   Item(Token("rum"), []),
/// // ])
/// ```
pub fn parse_list(value: String) -> Result(List(Element), ParseError) {
  use <- bool.guard(!is_ascii(value), Error(NonAsciiInput))
  use #(members, _) <- result.try(parse_list_internal(value, [], skip_sp(value, 0)))
  Ok(members)
}

fn is_ascii(value: String) -> Bool {
  value
  |> string.to_utf_codepoints
  |> list.all(fn(cp) { string.utf_codepoint_to_int(cp) <= 127 })
}

/// Parses a Structured Fields Dictionary header value (RFC 9651 §4.2.2).
///
/// A dictionary is an ordered map represented as a comma-separated sequence of
/// `key=value` pairs (or bare `key` for a boolean-true shorthand). Keys must
/// follow parameter-key syntax. Returns the entries in the order they appear in
/// the header.
///
/// Example:
///
/// ```gleam
/// parse_dictionary("en=\"Foo\", de=\"Bar\"")
/// // -> Ok([
/// //   #("en", Item(BareString("Foo"), [])),
/// //   #("de", Item(BareString("Bar"), [])),
/// // ])
/// ```
pub fn parse_dictionary(
  value: String,
) -> Result(List(#(String, Element)), ParseError) {
  use <- bool.guard(!is_ascii(value), Error(NonAsciiInput))
  use #(dict, _) <- result.try(parse_dictionary_internal(value, skip_sp(value, 0), []))
  Ok(dict)
}

fn parse_dictionary_internal(
  value: String,
  current_position: Int,
  accumulated: List(#(String, Element)),
) -> Result(#(List(#(String, Element)), Int), ParseError) {
  let end = string.length(value)
  let is_end = current_position >= end

  case is_end {
    True -> Ok(#(accumulated, current_position))
    False -> {
      use #(key, pos) <- result.try(parse_parameter_key(
        value,
        current_position,
        [],
      ))
      use #(member_value, pos) <- result.try(parse_dictionary_member_value(
        value,
        pos,
      ))
      let accumulated = list.key_set(accumulated, key, member_value)

      let new_character_position = skip_whitespace(value, pos)
      case string.slice(value, new_character_position, 1) {
        "," -> {
          let skipped = skip_whitespace(value, new_character_position + 1)
          case skipped >= end {
            True -> Error(TrailingCommaError(new_character_position))
            False -> parse_dictionary_internal(value, skipped, accumulated)
          }
        }
        "" -> Ok(#(accumulated, new_character_position))
        _ -> Error(CommaExpectedError(new_character_position))
      }
    }
  }
}

fn parse_dictionary_member_value(
  value: String,
  current_position: Int,
) -> Result(#(Element, Int), ParseError) {
  case string.slice(value, current_position, 1) {
    "=" -> parse_item_or_inner_list(value, current_position + 1)
    _ -> {
      use #(params, pos) <- result.try(
        parse_parameters(value, current_position, []),
      )
      Ok(#(Item(value: Boolean(True), parameters: params), pos))
    }
  }
}

fn parse_list_internal(
  value: String,
  members: List(Element),
  current_position: Int,
) -> Result(#(List(Element), Int), ParseError) {
  let end = string.length(value)
  let is_end = current_position >= end

  case is_end {
    True -> Ok(#(list.reverse(members), current_position))
    False -> {
      use #(parsed_member, new_position) <- result.try(parse_item_or_inner_list(
        value,
        current_position,
      ))
      let members = [parsed_member, ..members]

      let new_character_position = skip_whitespace(value, new_position)
      case string.slice(value, new_character_position, 1) {
        "," -> {
          let skipped_position =
            skip_whitespace(value, new_character_position + 1)
          case skipped_position >= end {
            True -> Error(TrailingCommaError(new_character_position))
            False -> parse_list_internal(value, members, skipped_position)
          }
        }
        "" -> Ok(#(list.reverse(members), new_character_position))
        _ -> Error(CommaExpectedError(new_character_position))
      }
    }
  }
}

fn parse_item_or_inner_list(
  value: String,
  current_position: Int,
) -> Result(#(Element, Int), ParseError) {
  case string.slice(value, current_position, 1) {
    "(" -> parse_inner_list(value, current_position + 1, [])
    _ -> parse_item_internal(value, current_position)
  }
}

fn parse_inner_list(
  value: String,
  current_position: Int,
  accumulated: List(Element),
) -> Result(#(Element, Int), ParseError) {
  let pos = skip_sp(value, current_position)
  let next_char = string.slice(value, pos, 1)

  case next_char {
    ")" -> {
      use #(params, pos) <- result.try(parse_parameters(value, pos + 1, []))
      Ok(#(InnerList(value: list.reverse(accumulated), parameters: params), pos))
    }
    "" -> Error(UnclosedInnerList(pos))
    _ -> {
      use #(item, pos) <- result.try(parse_item_internal(value, pos))
      let after = string.slice(value, pos, 1)
      case after {
        " " | ")" -> parse_inner_list(value, pos, [item, ..accumulated])
        "" -> Error(UnclosedInnerList(pos))
        _ -> Error(UnrecognizedItemType(pos))
      }
    }
  }
}

/// Parses a single Structured Fields Item (RFC 9651 §4.2.3).
///
/// An item is a bare item value followed by an optional semicolon-delimited
/// parameter list. Returns the bare value and the parameters as a tuple.
///
/// Example:
///
/// ```gleam
/// parse_item("42;q=0.9")
/// // -> Ok(#(Integer(42), [Parameter("q", Decimal(0.9))]))
/// ```
pub fn parse_item(
  value: String,
) -> Result(#(BareItem, List(Parameter)), ParseError) {
  let start = skip_sp(value, 0)
  use #(bare_item, pos) <- result.try(parse_bare_item(value, start))
  use #(parameters, pos) <- result.try(parse_parameters(value, pos, []))
  let end = skip_sp(value, pos)
  case end >= string.length(value) {
    True -> Ok(#(bare_item, parameters))
    False -> Error(UnrecognizedItemType(end))
  }
}

fn parse_item_internal(
  value: String,
  current_position: Int,
) -> Result(#(Element, Int), ParseError) {
  use #(bare_item, new_position) <- result.try(parse_bare_item(
    value,
    current_position,
  ))
  use #(parameters, new_position) <- result.try(
    parse_parameters(value, new_position, []),
  )
  Ok(#(Item(value: bare_item, parameters: parameters), new_position))
}

fn parse_bare_item(
  value: String,
  current_position: Int,
) -> Result(#(BareItem, Int), ParseError) {
  let next_char = string.slice(value, current_position, 1)
  let is_digit = should_parse_as_digit(next_char)
  let is_token = should_parse_as_token(next_char)

  case next_char {
    "\"" -> {
      use #(s, pos) <- result.try(parse_string(value, current_position + 1, []))
      Ok(#(BareString(s), pos))
    }
    "?" -> {
      use #(b, pos) <- result.try(parse_boolean(value, current_position + 1))
      Ok(#(Boolean(b), pos))
    }
    "@" -> {
      use #(n, pos) <- result.try(parse_date(value, current_position + 1))
      Ok(#(Integer(n), pos))
    }
    ":" -> {
      use #(bits, pos) <- result.try(
        parse_byte_sequence(value, current_position + 1, []),
      )
      Ok(#(ByteSequence(bits), pos))
    }
    "%" -> {
      case string.slice(value, current_position + 1, 1) {
        "\"" -> {
          use #(s, pos) <- result.try(
            parse_display_string(value, current_position + 2, <<>>),
          )
          Ok(#(DisplayString(s), pos))
        }
        _ -> Error(InvalidDisplayString(current_position))
      }
    }
    _ if is_digit -> {
      use #(v, pos) <- result.try(
        parse_integer_or_decimal(value, current_position, "", 1),
      )
      case v {
        IsInteger(n) -> Ok(#(Integer(n), pos))
        IsDecimal(f) -> Ok(#(Decimal(f), pos))
      }
    }
    _ if is_token -> {
      use #(s, pos) <- result.try(parse_token(value, current_position, []))
      Ok(#(Token(s), pos))
    }
    _ -> Error(UnrecognizedItemType(current_position))
  }
}

fn parse_parameters(
  value: String,
  current_position: Int,
  accumulated: List(Parameter),
) -> Result(#(List(Parameter), Int), ParseError) {
  let next_char = string.slice(value, current_position, 1)

  case next_char {
    ";" -> {
      let pos = skip_sp(value, current_position + 1)
      use #(key, pos) <- result.try(parse_parameter_key(value, pos, []))
      case string.slice(value, pos, 1) {
        "=" -> {
          use #(param_value, pos) <- result.try(parse_bare_item(value, pos + 1))
          let param = Parameter(name: key, value: param_value)
          parse_parameters(
            value,
            pos,
            update_or_append_param(accumulated, param),
          )
        }
        _ -> {
          let param = Parameter(name: key, value: Boolean(True))
          parse_parameters(
            value,
            pos,
            update_or_append_param(accumulated, param),
          )
        }
      }
    }
    _ -> Ok(#(accumulated, current_position))
  }
}

fn parse_parameter_key(
  value: String,
  current_position: Int,
  accumulated: List(String),
) -> Result(#(String, Int), ParseError) {
  let next_char = string.slice(value, current_position, 1)
  let is_start = list.is_empty(accumulated)
  let is_valid = case is_start {
    True -> is_parameter_key_start_char(next_char)
    False -> is_parameter_key_char(next_char)
  }

  case next_char {
    "" if is_start -> Error(InvalidParameterKey(current_position))
    "" ->
      Ok(#(string.concat(list.reverse(accumulated)), current_position))
    _ if is_valid ->
      parse_parameter_key(value, current_position + 1, [next_char, ..accumulated])
    _ if is_start -> Error(InvalidParameterKey(current_position))
    _ -> Ok(#(string.concat(list.reverse(accumulated)), current_position))
  }
}

fn parse_string(
  value: String,
  current_position: Int,
  accumulated: List(String),
) -> Result(#(String, Int), ParseError) {
  let next_char = string.slice(value, current_position, 1)
  let code =
    next_char
    |> string.to_utf_codepoints
    |> list.first
    |> result.map(string.utf_codepoint_to_int)
    |> result.unwrap(0)
  let is_invalid_code_point = code < 32 || code >= 127

  case next_char {
    "\\" -> {
      let next_char = string.slice(value, current_position + 1, 1)
      case next_char {
        "\\" ->
          parse_string(value, current_position + 2, ["\\", ..accumulated])
        "\"" ->
          parse_string(value, current_position + 2, ["\"", ..accumulated])
        _ -> Error(InvalidStringInput(current_position))
      }
    }
    "\"" ->
      Ok(#(string.concat(list.reverse(accumulated)), current_position + 1))
    "" -> Error(InvalidStringInput(current_position))
    // Reached end without closing quote
    _ if is_invalid_code_point -> Error(InvalidStringInput(current_position))
    _ -> parse_string(value, current_position + 1, [next_char, ..accumulated])
  }
}

fn parse_token(
  value: String,
  current_position: Int,
  accumulated: List(String),
) -> Result(#(String, Int), ParseError) {
  let next_char = string.slice(value, current_position, 1)
  let is_still_token = is_token_char(next_char)

  case next_char {
    "" -> Ok(#(string.concat(list.reverse(accumulated)), current_position))
    _ if is_still_token ->
      parse_token(value, current_position + 1, [next_char, ..accumulated])
    _ -> Ok(#(string.concat(list.reverse(accumulated)), current_position))
  }
}

fn parse_boolean(
  value: String,
  current_position: Int,
) -> Result(#(Bool, Int), ParseError) {
  let next_char = string.slice(value, current_position, 1)

  case next_char {
    "1" -> Ok(#(True, current_position + 1))
    "0" -> Ok(#(False, current_position + 1))
    _ -> Error(InvalidBoolean(current_position))
  }
}

fn parse_byte_sequence(
  value: String,
  current_position: Int,
  accumulated: List(String),
) -> Result(#(BitArray, Int), ParseError) {
  let next_char = string.slice(value, current_position, 1)

  case next_char {
    "" -> Error(InvalidByteSequence(current_position))
    ":" -> {
      let all_valid = list.all(accumulated, is_base64_char)
      case all_valid {
        False -> Error(InvalidByteSequence(current_position))
        True ->
          case
            bit_array.base64_decode(string.concat(list.reverse(accumulated)))
          {
            Ok(bits) -> Ok(#(bits, current_position + 1))
            Error(_) -> Error(InvalidByteSequence(current_position))
          }
      }
    }
    _ ->
      parse_byte_sequence(value, current_position + 1, [next_char, ..accumulated])
  }
}

fn parse_display_string(
  value: String,
  current_position: Int,
  accumulated: BitArray,
) -> Result(#(String, Int), ParseError) {
  let next_char = string.slice(value, current_position, 1)

  case next_char {
    "" -> Error(InvalidDisplayString(current_position))
    "\"" ->
      case bit_array.to_string(accumulated) {
        Ok(s) -> Ok(#(s, current_position + 1))
        Error(_) -> Error(InvalidDisplayString(current_position))
      }
    "%" -> {
      let hex1 = string.slice(value, current_position + 1, 1)
      let hex2 = string.slice(value, current_position + 2, 1)
      case is_hex_digit(hex1) && is_hex_digit(hex2) {
        False -> Error(InvalidDisplayString(current_position))
        True ->
          case int.base_parse(hex1 <> hex2, 16) {
            Error(_) -> Error(InvalidDisplayString(current_position))
            Ok(byte) ->
              parse_display_string(
                value,
                current_position + 3,
                bit_array.append(accumulated, <<byte>>),
              )
          }
      }
    }
    _ -> {
      let code =
        next_char
        |> string.to_utf_codepoints
        |> list.first
        |> result.map(string.utf_codepoint_to_int)
        |> result.unwrap(0)
      case code >= 0x20 && code <= 0x7e {
        False -> Error(InvalidDisplayString(current_position))
        True ->
          parse_display_string(
            value,
            current_position + 1,
            bit_array.append(accumulated, <<code>>),
          )
      }
    }
  }
}

fn parse_date(
  value: String,
  current_position: Int,
) -> Result(#(Int, Int), ParseError) {
  use #(v, new_position) <- result.try(
    parse_integer_or_decimal(value, current_position, "", 1),
  )
  case v {
    IsInteger(n) -> Ok(#(n, new_position))
    IsDecimal(_) -> Error(WrongDateFormat(current_position))
  }
}

fn parse_integer_or_decimal(
  value: String,
  current_position: Int,
  input_number: String,
  sign: Int,
) -> Result(#(IntegerOrDecimal, Int), ParseError) {
  let next_char = string.slice(value, current_position, 1)
  let digit = should_parse_as_digit(next_char)

  case next_char {
    "" ->
      finalize_integer_or_decimal_parsing(input_number, sign, current_position)
    "-" if input_number == "" && sign == 1 ->
      parse_integer_or_decimal(value, current_position + 1, input_number, -1)
    "-" ->
      finalize_integer_or_decimal_parsing(input_number, sign, current_position)
    _ if digit ->
      parse_integer_or_decimal(
        value,
        current_position + 1,
        input_number <> next_char,
        sign,
      )
    "." ->
      case string.contains(input_number, ".") {
        True -> Error(WrongDecimalOrIntegerInput(current_position))
        False ->
          parse_integer_or_decimal(
            value,
            current_position + 1,
            input_number <> next_char,
            sign,
          )
      }
    _ ->
      finalize_integer_or_decimal_parsing(input_number, sign, current_position)
  }
}

fn finalize_integer_or_decimal_parsing(
  input_number: String,
  sign: Int,
  current_position: Int,
) -> Result(#(IntegerOrDecimal, Int), ParseError) {
  let is_decimal = string.contains(input_number, ".")
  let without_period = string.replace(input_number, ".", "")
  let last_char_is_period = string.slice(input_number, -1, 1) == "."
  let decimals_after_period =
    string.split(input_number, ".")
    |> list.last
    |> result.unwrap("")
    |> string.length
  let integer_digits_before_period =
    string.split(input_number, ".")
    |> list.first
    |> result.unwrap("")
    |> string.length
  let too_long = case is_decimal {
    True -> integer_digits_before_period > 12
    False -> string.length(without_period) > 15
  }
  let more_than_3_decimals = is_decimal && decimals_after_period > 3
  let is_valid = !last_char_is_period && !more_than_3_decimals && !too_long

  case is_valid {
    True -> {
      case is_decimal {
        True -> {
          parse_decimal_result(input_number, sign, current_position)
        }
        False -> {
          parse_integer_result(input_number, sign, current_position)
        }
      }
    }
    False -> Error(WrongDecimalOrIntegerInput(current_position))
  }
}

fn parse_decimal_result(
  input_number: String,
  sign: Int,
  current_position: Int,
) -> Result(#(IntegerOrDecimal, Int), ParseError) {
  use n <- result.try(
    float.parse(input_number)
    |> result.map_error(fn(_) { WrongDecimalOrIntegerInput(current_position) }),
  )
  Ok(#(IsDecimal(sign |> int.to_float |> float.multiply(n)), current_position))
}

fn parse_integer_result(
  input_number: String,
  sign: Int,
  current_position: Int,
) -> Result(#(IntegerOrDecimal, Int), ParseError) {
  use n <- result.try(
    int.parse(input_number)
    |> result.map_error(fn(_) { WrongDecimalOrIntegerInput(current_position) }),
  )
  Ok(#(IsInteger(sign * n), current_position))
}

fn skip_whitespace(value: String, current_position: Int) -> Int {
  let char = string.slice(value, current_position, 1)

  case char {
    " " -> skip_whitespace(value, current_position + 1)
    "\t" -> skip_whitespace(value, current_position + 1)
    _ -> current_position
  }
}

fn should_parse_as_digit(character: String) -> Bool {
  let digits = "0123456789-"
  string.contains(digits, character)
}

fn should_parse_as_token(character: String) -> Bool {
  let token_characters = "*abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
  string.contains(token_characters, character)
}

fn is_token_char(character: String) -> Bool {
  let token_characters =
    ":/!#$%&'*+-.^_`|~0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
  string.contains(token_characters, character)
}

fn is_hex_digit(char: String) -> Bool {
  let ascii_chars = "0123456789abcdef"
  string.contains(ascii_chars, char)
}

fn is_parameter_key_start_char(char: String) -> Bool {
  let parameter_key_start_chars = "abcdefghijklmnopqrstuvwxyz*"
  string.contains(parameter_key_start_chars, char)
}

fn is_parameter_key_char(char: String) -> Bool {
  let parameter_key_chars = "abcdefghijklmnopqrstuvwxyz0123456789_-.*"
  string.contains(parameter_key_chars, char)
}

fn skip_sp(value: String, current_position: Int) -> Int {
  case string.slice(value, current_position, 1) {
    " " -> skip_sp(value, current_position + 1)
    _ -> current_position
  }
}

fn is_base64_char(char: String) -> Bool {
  let base64_chars =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/="
  string.contains(base64_chars, char)
}

fn update_or_append_param(
  accumulated: List(Parameter),
  param: Parameter,
) -> List(Parameter) {
  case accumulated {
    [] -> [param]
    [p, ..rest] if p.name == param.name -> [param, ..rest]
    [p, ..rest] -> [p, ..update_or_append_param(rest, param)]
  }
}
