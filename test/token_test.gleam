import structured_fields/parser
import structured_fields/serializer
import structured_fields/types.{Item, Token}

pub fn parse_token_simple_test() {
  assert parser.parse_list("foo") == Ok([Item(Token("foo"), [])])
}

pub fn parse_token_with_colon_test() {
  assert parser.parse_list("foo:bar") == Ok([Item(Token("foo:bar"), [])])
}

pub fn parse_token_with_slash_test() {
  assert parser.parse_list("text/plain") == Ok([Item(Token("text/plain"), [])])
}

pub fn parse_token_uppercase_test() {
  assert parser.parse_list("FooBar") == Ok([Item(Token("FooBar"), [])])
}

pub fn parse_token_asterisk_start_test() {
  assert parser.parse_list("*foo") == Ok([Item(Token("*foo"), [])])
}

pub fn serialize_token_simple_test() {
  assert serializer.serialize_item(Item(Token("foo"), [])) == "foo"
}

pub fn serialize_token_with_slash_test() {
  assert serializer.serialize_item(Item(Token("text/plain"), []))
    == "text/plain"
}

pub fn serialize_token_asterisk_start_test() {
  assert serializer.serialize_item(Item(Token("*foo"), [])) == "*foo"
}
