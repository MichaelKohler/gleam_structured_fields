import structured_fields/errors.{
  CommaExpectedError, TrailingCommaError, UnrecognizedItemType,
}
import structured_fields/parser
import structured_fields/types.{BareString, FieldList, Integer, Item, Token}

pub fn parse_list_single_item_test() {
  assert parser.parse_list("1") == Ok(FieldList([Item(Integer(1), [])]))
}

pub fn parse_list_multiple_items_test() {
  assert parser.parse_list("1, 2, 3")
    == Ok(
      FieldList([
        Item(Integer(1), []),
        Item(Integer(2), []),
        Item(Integer(3), []),
      ]),
    )
}

pub fn parse_list_mixed_types_test() {
  assert parser.parse_list("1, \"two\", foo")
    == Ok(
      FieldList([
        Item(Integer(1), []),
        Item(BareString("two"), []),
        Item(Token("foo"), []),
      ]),
    )
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
