import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import structured_fields/errors.{
  type ParseError, CommaExpectedError, InvalidBoolean, InvalidStringInput,
  TrailingCommaError, UnrecognizedItemType, WrongDecimalOrIntegerInput,
}
import structured_fields/types.{
  type BareItem, type Element, type Parameter, BareString, Boolean, Decimal,
  FieldList, InnerList, Integer, Item, Token,
}

pub fn parse_list(value: String) -> Result(Element, ParseError) {
  let result = parse_list_internal(value, [], 0)

  case result {
    Ok(#(field_list, _)) -> Ok(field_list)
    Error(e) -> Error(e)
  }
}

fn parse_list_internal(
  value: String,
  members: List(Element),
  current_position: Int,
) -> Result(#(Element, Int), ParseError) {
  let end = string.length(value) - 1
  let is_end = current_position >= end

  case is_end {
    True -> Ok(#(FieldList(value: members), current_position))
    False -> {
      use #(parsed_member, new_position) <- result.try(parse_item_or_inner_list(
        value,
        current_position,
      ))
      let members = list.append(members, [parsed_member])

      io.println(
        "Parsed member: "
        <> string.inspect(parsed_member)
        <> ".. New position: "
        <> int.to_string(new_position),
      )

      let skipped_position = skip_whitespace(value, new_position)
      let next_char = string.slice(value, skipped_position, 1)

      io.println(
        "Current position: "
        <> int.to_string(skipped_position)
        <> ".. Members: "
        <> string.inspect(members)
        <> ".. Next char: "
        <> next_char,
      )

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
        _ -> {
          io.println(
            "Next char: "
            <> next_char
            <> ".. Index: "
            <> int.to_string(skipped_position),
          )
          Error(CommaExpectedError(skipped_position))
        }
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
    "(" -> parse_inner_list(value, current_position + 1)
    _ -> parse_item(value, current_position)
  }

  result
}

fn parse_inner_list(
  value: String,
  current_position: Int,
) -> Result(#(Element, Int), ParseError) {
  let inner_list = InnerList(value: [], parameters: [])
  let result = #(inner_list, current_position)

  Ok(result)
}

fn parse_item(
  value: String,
  current_position: Int,
) -> Result(#(Element, Int), ParseError) {
  io.println(
    "Parsing item at position: "
    <> int.to_string(current_position)
    <> ".. Value: "
    <> string.slice(value, current_position, 10),
  )
  use #(bare_item, new_position) <- result.try(parse_bare_item(
    value,
    current_position,
  ))
  use #(parameters, new_position) <- result.try(parse_parameters(
    value,
    new_position,
  ))

  let item = Item(value: bare_item, parameters: parameters)
  let result = #(item, new_position)

  Ok(result)
}

fn parse_bare_item(
  value: String,
  current_position: Int,
) -> Result(#(BareItem, Int), ParseError) {
  io.println(
    "Parsing bare item at position: "
    <> int.to_string(current_position)
    <> ".. Value: "
    <> string.slice(value, current_position, 10),
  )
  let next_char = string.slice(value, current_position, 1)
  let is_digit = should_parse_as_digit(next_char)
  let is_token = should_parse_as_token(next_char)

  case next_char {
    _ if is_digit -> parse_integer_or_decimal(value, current_position, "", 1)
    "\"" -> parse_string(value, current_position + 1, "")
    _ if is_token -> parse_token(value, current_position, "")
    "?" -> parse_boolean(value, current_position + 1)
    _ -> Error(UnrecognizedItemType(current_position))
  }
}

fn parse_parameters(
  value: String,
  current_position: Int,
) -> Result(#(List(Parameter), Int), ParseError) {
  let parameter_list = []
  let result = #(parameter_list, current_position)

  Ok(result)
}

fn parse_string(
  value: String,
  current_position: Int,
  current_string: String,
) -> Result(#(BareItem, Int), ParseError) {
  io.println(
    "Parsing string at position: "
    <> int.to_string(current_position)
    <> ".. Value: "
    <> string.slice(value, current_position, 10),
  )
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
          let new_string = string.append(current_string, "\\\\")
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
  io.println(
    "Parsing token at position: "
    <> int.to_string(current_position)
    <> ".. Value: "
    <> string.slice(value, current_position, 10),
  )
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
  let more_than_3_decimals = decimals_after_period > 3
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
