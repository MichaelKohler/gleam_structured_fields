import structured_fields/errors.{InvalidStringInput, UnrecognizedItemType}
import structured_fields/parser
import structured_fields/types.{
  BareString, Boolean, ByteSequence, Decimal, DisplayString, Integer, Parameter,
  Token,
}

pub fn parse_item_integer_test() {
  assert parser.parse_item("42") == Ok(#(Integer(42), []))
}

pub fn parse_item_negative_integer_test() {
  assert parser.parse_item("-5") == Ok(#(Integer(-5), []))
}

pub fn parse_item_decimal_test() {
  assert parser.parse_item("1.5") == Ok(#(Decimal(1.5), []))
}

pub fn parse_item_string_test() {
  assert parser.parse_item("\"hello\"") == Ok(#(BareString("hello"), []))
}

pub fn parse_item_boolean_true_test() {
  assert parser.parse_item("?1") == Ok(#(Boolean(True), []))
}

pub fn parse_item_boolean_false_test() {
  assert parser.parse_item("?0") == Ok(#(Boolean(False), []))
}

pub fn parse_item_token_test() {
  assert parser.parse_item("foo") == Ok(#(Token("foo"), []))
}

pub fn parse_item_byte_sequence_test() {
  assert parser.parse_item(":aGVsbG8=:") == Ok(#(ByteSequence(<<"hello">>), []))
}

pub fn parse_item_display_string_test() {
  assert parser.parse_item("%\"hello\"") == Ok(#(DisplayString("hello"), []))
}

pub fn parse_item_with_parameter_test() {
  assert parser.parse_item("foo;n=1")
    == Ok(#(Token("foo"), [Parameter("n", Integer(1))]))
}

pub fn parse_item_with_multiple_parameters_test() {
  assert parser.parse_item("foo;a=1;b=2")
    == Ok(
      #(Token("foo"), [Parameter("a", Integer(1)), Parameter("b", Integer(2))]),
    )
}

pub fn parse_item_unrecognized_type_test() {
  assert parser.parse_item("[bad") == Error(UnrecognizedItemType(0))
}

pub fn parse_item_unclosed_string_test() {
  assert parser.parse_item("\"unclosed") == Error(InvalidStringInput(9))
}
