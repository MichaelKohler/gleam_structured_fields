import structured_fields/errors.{InvalidParameterKey}
import structured_fields/parser
import structured_fields/types.{
  BareString, Boolean, FieldList, Integer, Item, Parameter, Token,
}

pub fn parse_parameter_integer_value_test() {
  assert parser.parse_list("foo; n=42")
    == Ok(FieldList([Item(Token("foo"), [Parameter("n", Integer(42))])]))
}

pub fn parse_parameter_boolean_shorthand_test() {
  assert parser.parse_list("foo; flag")
    == Ok(FieldList([Item(Token("foo"), [Parameter("flag", Boolean(True))])]))
}

pub fn parse_parameter_boolean_false_test() {
  assert parser.parse_list("foo; flag=?0")
    == Ok(FieldList([Item(Token("foo"), [Parameter("flag", Boolean(False))])]))
}

pub fn parse_parameter_string_value_test() {
  assert parser.parse_list("foo; key=\"bar\"")
    == Ok(
      FieldList([Item(Token("foo"), [Parameter("key", BareString("bar"))])]),
    )
}

pub fn parse_parameter_token_value_test() {
  assert parser.parse_list("foo; type=text/plain")
    == Ok(
      FieldList([Item(Token("foo"), [Parameter("type", Token("text/plain"))])]),
    )
}

pub fn parse_parameter_multiple_test() {
  assert parser.parse_list("foo; a=1; b=?0")
    == Ok(
      FieldList([
        Item(Token("foo"), [
          Parameter("a", Integer(1)),
          Parameter("b", Boolean(False)),
        ]),
      ]),
    )
}

pub fn parse_parameter_invalid_key_test() {
  assert parser.parse_list("foo; 1bad") == Error(InvalidParameterKey(5))
}
