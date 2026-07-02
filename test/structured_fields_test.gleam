import gleeunit
import structured_fields/errors.{InvalidDisplayString}
import structured_fields/parser
import structured_fields/types.{DisplayString, FieldList, Item}

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn parse_display_string_ascii_test() {
  assert parser.parse_list("%\"hello\"") == Ok(FieldList([Item(DisplayString("hello"), [])]))
}

pub fn parse_display_string_multibyte_test() {
  assert parser.parse_list("%\"caf%C3%A9\"") == Ok(FieldList([Item(DisplayString("café"), [])]))
}

pub fn parse_display_string_list_test() {
  assert parser.parse_list("%\"hello\", %\"world\"")
    == Ok(FieldList([Item(DisplayString("hello"), []), Item(DisplayString("world"), [])]))
}

pub fn parse_display_string_control_char_test() {
  assert parser.parse_list("%\"\u{0001}\"") == Error(InvalidDisplayString(2))
}

pub fn parse_display_string_unterminated_test() {
  assert parser.parse_list("%\"abc") == Error(InvalidDisplayString(5))
}

pub fn parse_display_string_invalid_hex_test() {
  assert parser.parse_list("%\"%GG\"") == Error(InvalidDisplayString(2))
}
