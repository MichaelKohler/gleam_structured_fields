import structured_fields/errors.{InvalidParameterKey}
import structured_fields/parser
import structured_fields/serializer
import structured_fields/types.{
  BareString, Boolean, Integer, Item, Parameter, Token,
}

pub fn parse_parameter_integer_value_test() {
  assert parser.parse_list("foo; n=42")
    == Ok([Item(Token("foo"), [Parameter("n", Integer(42))])])
}

pub fn parse_parameter_boolean_shorthand_test() {
  assert parser.parse_list("foo; flag")
    == Ok([Item(Token("foo"), [Parameter("flag", Boolean(True))])])
}

pub fn parse_parameter_boolean_false_test() {
  assert parser.parse_list("foo; flag=?0")
    == Ok([Item(Token("foo"), [Parameter("flag", Boolean(False))])])
}

pub fn parse_parameter_string_value_test() {
  assert parser.parse_list("foo; key=\"bar\"")
    == Ok([Item(Token("foo"), [Parameter("key", BareString("bar"))])])
}

pub fn parse_parameter_token_value_test() {
  assert parser.parse_list("foo; type=text/plain")
    == Ok([Item(Token("foo"), [Parameter("type", Token("text/plain"))])])
}

pub fn parse_parameter_multiple_test() {
  assert parser.parse_list("foo; a=1; b=?0")
    == Ok([
      Item(Token("foo"), [
        Parameter("a", Integer(1)),
        Parameter("b", Boolean(False)),
      ]),
    ])
}

pub fn parse_parameter_invalid_key_test() {
  assert parser.parse_list("foo; 1bad") == Error(InvalidParameterKey(5))
}

pub fn serialize_parameter_boolean_shorthand_test() {
  assert serializer.serialize_parameters([Parameter("flag", Boolean(True))])
    == ";flag"
}

pub fn serialize_parameter_integer_value_test() {
  assert serializer.serialize_parameters([Parameter("n", Integer(42))])
    == ";n=42"
}

pub fn serialize_parameter_boolean_false_test() {
  assert serializer.serialize_parameters([Parameter("flag", Boolean(False))])
    == ";flag=?0"
}

pub fn serialize_parameter_string_value_test() {
  assert serializer.serialize_parameters([Parameter("key", BareString("bar"))])
    == ";key=\"bar\""
}

pub fn serialize_parameter_token_value_test() {
  assert serializer.serialize_parameters([
      Parameter("type", Token("text/plain")),
    ])
    == ";type=text/plain"
}

pub fn serialize_parameter_multiple_test() {
  assert serializer.serialize_parameters([
      Parameter("a", Integer(1)),
      Parameter("b", Boolean(False)),
    ])
    == ";a=1;b=?0"
}

pub fn serialize_item_with_parameters_test() {
  assert serializer.serialize_item(
      Item(Token("foo"), [Parameter("n", Integer(42))]),
    )
    == "foo;n=42"
}
