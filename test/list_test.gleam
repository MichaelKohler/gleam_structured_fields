import structured_fields/errors.{
  CommaExpectedError, NonAsciiInput, TrailingCommaError, UnrecognizedItemType,
}
import structured_fields/parser
import structured_fields/serializer
import structured_fields/types.{
  BareString, InnerList, Integer, Item, Parameter, Token,
}

pub fn parse_list_single_item_test() {
  assert parser.parse_list("1") == Ok([Item(Integer(1), [])])
}

pub fn parse_list_multiple_items_test() {
  assert parser.parse_list("1, 2, 3")
    == Ok([Item(Integer(1), []), Item(Integer(2), []), Item(Integer(3), [])])
}

pub fn parse_list_mixed_types_test() {
  assert parser.parse_list("1, \"two\", foo")
    == Ok([
      Item(Integer(1), []),
      Item(BareString("two"), []),
      Item(Token("foo"), []),
    ])
}

pub fn parse_list_trailing_comma_test() {
  assert parser.parse_list("1, 2,") == Error(TrailingCommaError(5))
}

pub fn parse_list_missing_comma_test() {
  assert parser.parse_list("1 2") == Error(CommaExpectedError(2))
}

pub fn parse_list_unrecognized_item_test() {
  assert parser.parse_list("[bad") == Error(UnrecognizedItemType(0))
}

pub fn parse_list_non_ascii_test() {
  assert parser.parse_list("café") == Error(NonAsciiInput)
}

pub fn serialize_list_single_item_test() {
  assert serializer.serialize_list([Item(Integer(1), [])]) == "1"
}

pub fn serialize_list_multiple_items_test() {
  assert serializer.serialize_list([
      Item(Integer(1), []),
      Item(Integer(2), []),
      Item(Integer(3), []),
    ])
    == "1, 2, 3"
}

pub fn serialize_list_mixed_types_test() {
  assert serializer.serialize_list([
      Item(Integer(1), []),
      Item(BareString("two"), []),
      Item(Token("foo"), []),
    ])
    == "1, \"two\", foo"
}

pub fn serialize_list_with_inner_list_test() {
  assert serializer.serialize_list([
      InnerList([Item(Integer(1), []), Item(Integer(2), [])], []),
      Item(Integer(3), []),
    ])
    == "(1 2), 3"
}

pub fn serialize_list_item_with_params_test() {
  assert serializer.serialize_list([
      Item(Token("foo"), [Parameter("n", Integer(1))]),
    ])
    == "foo;n=1"
}
