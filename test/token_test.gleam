import structured_fields/parser
import structured_fields/types.{FieldList, Item, Token}

pub fn parse_token_simple_test() {
  assert parser.parse_list("foo") == Ok(FieldList([Item(Token("foo"), [])]))
}

pub fn parse_token_with_colon_test() {
  assert parser.parse_list("foo:bar")
    == Ok(FieldList([Item(Token("foo:bar"), [])]))
}

pub fn parse_token_with_slash_test() {
  assert parser.parse_list("text/plain")
    == Ok(FieldList([Item(Token("text/plain"), [])]))
}

pub fn parse_token_uppercase_test() {
  assert parser.parse_list("FooBar")
    == Ok(FieldList([Item(Token("FooBar"), [])]))
}

pub fn parse_token_asterisk_start_test() {
  assert parser.parse_list("*foo") == Ok(FieldList([Item(Token("*foo"), [])]))
}
