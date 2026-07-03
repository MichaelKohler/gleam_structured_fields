import structured_fields/errors.{UnclosedInnerList}
import structured_fields/parser
import structured_fields/types.{
  Boolean, FieldList, InnerList, Integer, Item, Parameter, Token,
}

pub fn parse_inner_list_empty_test() {
  assert parser.parse_list("()")
    == Ok(FieldList([InnerList([], [])]))
}

pub fn parse_inner_list_single_item_test() {
  assert parser.parse_list("(1)")
    == Ok(FieldList([InnerList([Item(Integer(1), [])], [])]))
}

pub fn parse_inner_list_multiple_items_test() {
  assert parser.parse_list("(1 2 3)")
    == Ok(
      FieldList([
        InnerList(
          [Item(Integer(1), []), Item(Integer(2), []), Item(Integer(3), [])],
          [],
        ),
      ]),
    )
}

pub fn parse_inner_list_leading_trailing_whitespace_test() {
  assert parser.parse_list("( 1  2 )")
    == Ok(
      FieldList([
        InnerList([Item(Integer(1), []), Item(Integer(2), [])], []),
      ]),
    )
}

pub fn parse_inner_list_item_with_parameters_test() {
  assert parser.parse_list("(foo; flag)")
    == Ok(
      FieldList([
        InnerList([Item(Token("foo"), [Parameter("flag", Boolean(True))])], []),
      ]),
    )
}

pub fn parse_inner_list_with_parameters_test() {
  assert parser.parse_list("(1 2); level=5")
    == Ok(
      FieldList([
        InnerList(
          [Item(Integer(1), []), Item(Integer(2), [])],
          [Parameter("level", Integer(5))],
        ),
      ]),
    )
}

pub fn parse_inner_list_in_list_test() {
  assert parser.parse_list("(1 2), 3")
    == Ok(
      FieldList([
        InnerList([Item(Integer(1), []), Item(Integer(2), [])], []),
        Item(Integer(3), []),
      ]),
    )
}

pub fn parse_inner_list_unclosed_test() {
  assert parser.parse_list("(1 2") == Error(UnclosedInnerList(4))
}
