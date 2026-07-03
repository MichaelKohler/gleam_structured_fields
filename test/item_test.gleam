import structured_fields/errors.{InvalidStringInput, UnrecognizedItemType}
import structured_fields/parser
import structured_fields/types.{
  BareString, Boolean, ByteSequence, Decimal, DisplayString, Integer, Item,
  Parameter, Token,
}

pub fn parse_item_integer_test() {
  assert parser.parse_item("42") == Ok(#(Item(Integer(42), []), 2))
}

pub fn parse_item_negative_integer_test() {
  assert parser.parse_item("-5") == Ok(#(Item(Integer(-5), []), 2))
}

pub fn parse_item_decimal_test() {
  assert parser.parse_item("1.5") == Ok(#(Item(Decimal(1.5), []), 3))
}

pub fn parse_item_string_test() {
  assert parser.parse_item("\"hello\"")
    == Ok(#(Item(BareString("hello"), []), 7))
}

pub fn parse_item_boolean_true_test() {
  assert parser.parse_item("?1") == Ok(#(Item(Boolean(True), []), 2))
}

pub fn parse_item_boolean_false_test() {
  assert parser.parse_item("?0") == Ok(#(Item(Boolean(False), []), 2))
}

pub fn parse_item_token_test() {
  assert parser.parse_item("foo") == Ok(#(Item(Token("foo"), []), 3))
}

pub fn parse_item_byte_sequence_test() {
  assert parser.parse_item(":aGVsbG8=:")
    == Ok(#(Item(ByteSequence(<<"hello">>), []), 10))
}

pub fn parse_item_display_string_test() {
  assert parser.parse_item("%\"hello\"")
    == Ok(#(Item(DisplayString("hello"), []), 8))
}

pub fn parse_item_with_parameter_test() {
  assert parser.parse_item("foo;n=1")
    == Ok(#(Item(Token("foo"), [Parameter("n", Integer(1))]), 7))
}

pub fn parse_item_with_multiple_parameters_test() {
  assert parser.parse_item("foo;a=1;b=2")
    == Ok(#(
      Item(Token("foo"), [
        Parameter("a", Integer(1)),
        Parameter("b", Integer(2)),
      ]),
      11,
    ))
}

pub fn parse_item_unrecognized_type_test() {
  assert parser.parse_item("[bad") == Error(UnrecognizedItemType(0))
}

pub fn parse_item_unclosed_string_test() {
  assert parser.parse_item("\"unclosed") == Error(InvalidStringInput(9))
}
