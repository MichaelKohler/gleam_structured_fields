import gleam/bit_array
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
  Decimal, Dictionary, DisplayString, FieldList, InnerList, Integer, Item,
  Parameter, Token,
}

pub fn parse_list(value: String) -> Result(Element, ParseError) {
  case is_ascii(value) {
    False -> Error(NonAsciiInput)
    True -> {
      let result = parse_list_internal(value, [], 0)
      case result {
        Ok(#(field_list, _)) -> Ok(field_list)
        Error(e) -> Error(e)
      }
    }
  }
}

fn is_ascii(value: String) -> Bool {
  value
  |> string.to_utf_codepoints
  |> list.all(fn(cp) { string.utf_codepoint_to_int(cp) <= 127 })
}

pub fn parse_dictionary(value: String) -> Result(Element, ParseError) {
  case is_ascii(value) {
    False -> Error(NonAsciiInput)
    True -> {
      let result = parse_dictionary_internal(value, 0, [])
      case result {
        Ok(#(dict, _)) -> Ok(dict)
        Error(e) -> Error(e)
      }
    }
  }
}

fn parse_dictionary_internal(
  value: String,
  current_position: Int,
  accumulated: List(#(String, Element)),
) -> Result(#(Element, Int), ParseError) {
  let end = string.length(value)
  let is_end = current_position >= end

  case is_end {
    True -> Ok(#(Dictionary(value: accumulated), current_position))
    False -> {
      use #(key, pos) <- result.try(parse_parameter_key(
        value,
        current_position,
        "",
      ))
      use #(member_value, pos) <- result.try(parse_dictionary_member_value(
        value,
        pos,
      ))
      let accumulated = list.append(accumulated, [#(key, member_value)])

      let skipped = skip_whitespace(value, pos)
      case string.slice(value, skipped, 1) {
        "," -> {
          let skipped = skip_whitespace(value, skipped + 1)
          case skipped >= end {
            True -> Error(TrailingCommaError(skipped))
            False -> parse_dictionary_internal(value, skipped, accumulated)
          }
        }
        "" -> Ok(#(Dictionary(value: accumulated), skipped))
        _ -> Error(CommaExpectedError(skipped))
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
) -> Result(#(Element, Int), ParseError) {
  let end = string.length(value)
  let is_end = current_position >= end

  case is_end {
    True -> Ok(#(FieldList(value: members), current_position))
    False -> {
      use #(parsed_member, new_position) <- result.try(parse_item_or_inner_list(
        value,
        current_position,
      ))
      let members = list.append(members, [parsed_member])

      let skipped_position = skip_whitespace(value, new_position)
      let next_char = string.slice(value, skipped_position, 1)

      let result = case next_char {
        "," -> {
          let skipped_position = skip_whitespace(value, skipped_position + 1)
          let has_trailing_comma = skipped_position >= end

          let result = case has_trailing_comma {
            True -> Error(TrailingCommaError(skipped_position))
            False -> parse_list_internal(value, members, skipped_position)
          }

          result
        }
        "" -> Ok(#(FieldList(value: members), skipped_position))
        _ -> Error(CommaExpectedError(skipped_position))
      }

      result
    }
  }
}

fn parse_item_or_inner_list(
  value: String,
  current_position: Int,
) -> Result(#(Element, Int), ParseError) {
  let next_char = string.slice(value, current_position, 1)

  let result = case next_char {
    "(" -> parse_inner_list(value, current_position + 1, [])
    _ -> parse_item_internal(value, current_position)
  }

  result
}

fn parse_inner_list(
  value: String,
  current_position: Int,
  accumulated: List(Element),
) -> Result(#(Element, Int), ParseError) {
  let pos = skip_whitespace(value, current_position)
  let next_char = string.slice(value, pos, 1)

  case next_char {
    ")" -> {
      use #(params, pos) <- result.try(parse_parameters(value, pos + 1, []))
      Ok(#(InnerList(value: accumulated, parameters: params), pos))
    }
    "" -> Error(UnclosedInnerList(pos))
    _ -> {
      use #(item, pos) <- result.try(parse_item_internal(value, pos))
      parse_inner_list(value, pos, list.append(accumulated, [item]))
    }
  }
}

pub fn parse_item(value: String) -> Result(#(Element, Int), ParseError) {
  parse_item_internal(value, 0)
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

  let item = Item(value: bare_item, parameters: parameters)
  let result = #(item, new_position)

  Ok(result)
}

fn parse_bare_item(
  value: String,
  current_position: Int,
) -> Result(#(BareItem, Int), ParseError) {
  let next_char = string.slice(value, current_position, 1)
  let is_digit = should_parse_as_digit(next_char)
  let is_token = should_parse_as_token(next_char)

  case next_char {
    "\"" -> parse_string(value, current_position + 1, "")
    "?" -> parse_boolean(value, current_position + 1)
    "@" -> parse_date(value, current_position + 1)
    ":" -> parse_byte_sequence(value, current_position + 1, "")
    "%" -> {
      let next = string.slice(value, current_position + 1, 1)
      case next {
        "\"" -> parse_display_string(value, current_position + 2, <<>>)
        _ -> Error(InvalidDisplayString(current_position))
      }
    }
    _ if is_digit -> parse_integer_or_decimal(value, current_position, "", 1)
    _ if is_token -> parse_token(value, current_position, "")
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
      let pos = skip_whitespace(value, current_position + 1)
      use #(key, pos) <- result.try(parse_parameter_key(value, pos, ""))
      case string.slice(value, pos, 1) {
        "=" -> {
          use #(param_value, pos) <- result.try(parse_bare_item(value, pos + 1))
          let param = Parameter(name: key, value: param_value)
          parse_parameters(value, pos, list.append(accumulated, [param]))
        }
        _ -> {
          let param = Parameter(name: key, value: Boolean(True))
          parse_parameters(value, pos, list.append(accumulated, [param]))
        }
      }
    }
    _ -> Ok(#(accumulated, current_position))
  }
}

fn parse_parameter_key(
  value: String,
  current_position: Int,
  accumulated: String,
) -> Result(#(String, Int), ParseError) {
  let next_char = string.slice(value, current_position, 1)
  let is_start = accumulated == ""
  let is_valid = case is_start {
    True -> is_parameter_key_start_char(next_char)
    False -> is_parameter_key_char(next_char)
  }

  case next_char {
    "" if is_start -> Error(InvalidParameterKey(current_position))
    "" -> Ok(#(accumulated, current_position))
    _ if is_valid ->
      parse_parameter_key(value, current_position + 1, accumulated <> next_char)
    _ if is_start -> Error(InvalidParameterKey(current_position))
    _ -> Ok(#(accumulated, current_position))
  }
}

fn parse_string(
  value: String,
  current_position: Int,
  current_string: String,
) -> Result(#(BareItem, Int), ParseError) {
  let next_char = string.slice(value, current_position, 1)
  let code_point = next_char |> string.to_utf_codepoints |> list.first
  let code = case code_point {
    Ok(n) -> string.utf_codepoint_to_int(n)
    Error(_) -> 0
  }
  let is_invalid_code_point = code < 32 || code >= 127

  case next_char {
    "\\" -> {
      let next_char = string.slice(value, current_position + 1, 1)

      case next_char {
        "\\" -> {
          let new_string = string.append(current_string, "\\")
          parse_string(value, current_position + 2, new_string)
        }
        "\"" -> {
          let new_string = string.append(current_string, "\"")
          parse_string(value, current_position + 2, new_string)
        }
        _ -> Error(InvalidStringInput(current_position))
      }
    }
    "\"" -> Ok(#(BareString(current_string), current_position + 1))
    "" -> Error(InvalidStringInput(current_position))
    // Reached end without closing quote
    _ if is_invalid_code_point -> Error(InvalidStringInput(current_position))
    _ -> {
      let new_string = string.append(current_string, next_char)
      parse_string(value, current_position + 1, new_string)
    }
  }
}

fn parse_token(
  value: String,
  current_position: Int,
  current_string: String,
) -> Result(#(BareItem, Int), ParseError) {
  let next_char = string.slice(value, current_position, 1)
  let is_still_token = should_parse_as_token(next_char)

  case next_char {
    "" -> Ok(#(Token(current_string), current_position))
    _ if is_still_token -> {
      let new_string = string.append(current_string, next_char)
      parse_token(value, current_position + 1, new_string)
    }
    _ -> Ok(#(Token(current_string), current_position))
  }
}

fn parse_boolean(
  value: String,
  current_position: Int,
) -> Result(#(BareItem, Int), ParseError) {
  let next_char = string.slice(value, current_position, 1)

  case next_char {
    "1" -> Ok(#(Boolean(True), current_position + 1))
    "0" -> Ok(#(Boolean(False), current_position + 1))
    _ -> Error(InvalidBoolean(current_position))
  }
}

fn parse_byte_sequence(
  value: String,
  current_position: Int,
  accumulated: String,
) -> Result(#(BareItem, Int), ParseError) {
  let next_char = string.slice(value, current_position, 1)

  case next_char {
    "" -> Error(InvalidByteSequence(current_position))
    ":" ->
      case bit_array.base64_decode(accumulated) {
        Ok(bits) -> Ok(#(ByteSequence(bits), current_position + 1))
        Error(_) -> Error(InvalidByteSequence(current_position))
      }
    _ ->
      parse_byte_sequence(value, current_position + 1, accumulated <> next_char)
  }
}

fn parse_display_string(
  value: String,
  current_position: Int,
  accumulated: BitArray,
) -> Result(#(BareItem, Int), ParseError) {
  let next_char = string.slice(value, current_position, 1)

  case next_char {
    "" -> Error(InvalidDisplayString(current_position))
    "\"" ->
      case bit_array.to_string(accumulated) {
        Ok(s) -> Ok(#(DisplayString(s), current_position + 1))
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
      let code_point = next_char |> string.to_utf_codepoints |> list.first
      let code = case code_point {
        Ok(n) -> string.utf_codepoint_to_int(n)
        Error(_) -> 0
      }
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
) -> Result(#(BareItem, Int), ParseError) {
  let result = parse_integer_or_decimal(value, current_position, "", 1)

  case result {
    Ok(#(bare_item, new_position)) -> {
      case bare_item {
        Integer(n) -> Ok(#(Integer(n), new_position))
        Decimal(_) -> Error(WrongDateFormat(current_position))
        _ -> Error(WrongDateFormat(current_position))
      }
    }
    Error(e) -> Error(e)
  }
}

fn parse_integer_or_decimal(
  value: String,
  current_position: Int,
  input_number: String,
  sign: Int,
) -> Result(#(BareItem, Int), ParseError) {
  let next_char = string.slice(value, current_position, 1)
  let digit = should_parse_as_digit(next_char)

  case next_char {
    "" ->
      finalize_integer_or_decimal_parsing(input_number, sign, current_position)
    "-" -> {
      let sign = -1
      let new_position = current_position + 1
      parse_integer_or_decimal(value, new_position, input_number, sign)
    }
    _ if digit -> {
      let new_input_number = string.append(input_number, next_char)
      parse_integer_or_decimal(
        value,
        current_position + 1,
        new_input_number,
        sign,
      )
    }
    "." -> {
      let already_contains_period = string.contains(input_number, ".")
      case already_contains_period {
        True -> Error(WrongDecimalOrIntegerInput(current_position))
        False -> {
          let new_input_number = string.append(input_number, next_char)
          parse_integer_or_decimal(
            value,
            current_position + 1,
            new_input_number,
            sign,
          )
        }
      }
    }
    _ ->
      finalize_integer_or_decimal_parsing(input_number, sign, current_position)
  }
}

fn finalize_integer_or_decimal_parsing(
  input_number: String,
  sign: Int,
  current_position: Int,
) -> Result(#(BareItem, Int), ParseError) {
  let is_decimal = string.contains(input_number, ".")
  let without_period = string.replace(input_number, ".", "")
  let too_long = string.length(without_period) > 15
  let last_char_is_period = string.slice(input_number, -1, 1) == "."
  let decimals_after_period =
    string.split(input_number, ".")
    |> list.last
    |> result.unwrap("")
    |> string.length
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
) -> Result(#(BareItem, Int), ParseError) {
  let number = float.parse(input_number)

  case number {
    Error(_) -> Error(WrongDecimalOrIntegerInput(current_position))
    Ok(n) -> {
      let signed_number = sign |> int.to_float |> float.multiply(n)
      Ok(#(Decimal(signed_number), current_position))
    }
  }
}

fn parse_integer_result(
  input_number: String,
  sign: Int,
  current_position: Int,
) -> Result(#(BareItem, Int), ParseError) {
  let number = int.parse(input_number)

  case number {
    Error(_) -> Error(WrongDecimalOrIntegerInput(current_position))
    Ok(n) -> {
      let signed_number = sign * n
      Ok(#(Integer(signed_number), current_position))
    }
  }
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
  let token_characters =
    ":/!#$%&'*+\\-.^_`|~0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
  string.contains(token_characters, character)
}

fn is_hex_digit(char: String) -> Bool {
  string.contains("0123456789abcdefABCDEF", char)
}

fn is_parameter_key_start_char(char: String) -> Bool {
  string.contains("abcdefghijklmnopqrstuvwxyz*", char)
}

fn is_parameter_key_char(char: String) -> Bool {
  string.contains("abcdefghijklmnopqrstuvwxyz0123456789_-.*", char)
}
