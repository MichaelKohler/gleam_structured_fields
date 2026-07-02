import structured_fields/errors.{InvalidStringInput}
import structured_fields/parser
import structured_fields/types.{BareString, FieldList, Item}

pub fn parse_string_simple_test() {
  assert parser.parse_list("\"hello\"")
    == Ok(FieldList([Item(BareString("hello"), [])]))
}

pub fn parse_string_empty_test() {
  assert parser.parse_list("\"\"")
    == Ok(FieldList([Item(BareString(""), [])]))
}

pub fn parse_string_escaped_quote_test() {
  assert parser.parse_list("\"say \\\"hi\\\"\"")
    == Ok(FieldList([Item(BareString("say \"hi\""), [])]))
}

pub fn parse_string_escaped_backslash_test() {
  assert parser.parse_list("\"back\\\\slash\"")
    == Ok(FieldList([Item(BareString("back\\\\slash"), [])]))
}

pub fn parse_string_invalid_escape_test() {
  assert parser.parse_list("\"bad\\escape\"") == Error(InvalidStringInput(4))
}

pub fn parse_string_unterminated_test() {
  assert parser.parse_list("\"hello") == Error(InvalidStringInput(6))
}

pub fn parse_string_control_char_test() {
  assert parser.parse_list("\"\u{0001}\"") == Error(InvalidStringInput(1))
}
