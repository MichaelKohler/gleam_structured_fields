import structured_fields/errors.{
  CommaExpectedError, InvalidParameterKey, TrailingCommaError,
}
import structured_fields/parser
import structured_fields/serializer
import structured_fields/types.{Boolean, InnerList, Integer, Item, Parameter}

pub fn parse_dictionary_empty_test() {
  assert parser.parse_dictionary("") == Ok([])
}

pub fn parse_dictionary_single_entry_test() {
  assert parser.parse_dictionary("a=1") == Ok([#("a", Item(Integer(1), []))])
}

pub fn parse_dictionary_multiple_entries_test() {
  assert parser.parse_dictionary("a=1, b=2")
    == Ok([#("a", Item(Integer(1), [])), #("b", Item(Integer(2), []))])
}

pub fn parse_dictionary_boolean_shorthand_test() {
  assert parser.parse_dictionary("flag")
    == Ok([#("flag", Item(Boolean(True), []))])
}

pub fn parse_dictionary_shorthand_with_params_test() {
  assert parser.parse_dictionary("flag; x=2")
    == Ok([#("flag", Item(Boolean(True), [Parameter("x", Integer(2))]))])
}

pub fn parse_dictionary_entry_with_params_test() {
  assert parser.parse_dictionary("a=1; x=2")
    == Ok([#("a", Item(Integer(1), [Parameter("x", Integer(2))]))])
}

pub fn parse_dictionary_inner_list_value_test() {
  assert parser.parse_dictionary("a=(1 2)")
    == Ok([#("a", InnerList([Item(Integer(1), []), Item(Integer(2), [])], []))])
}

pub fn parse_dictionary_trailing_comma_test() {
  assert parser.parse_dictionary("a=1,") == Error(TrailingCommaError(3))
}

pub fn parse_dictionary_invalid_key_test() {
  assert parser.parse_dictionary("1bad=1") == Error(InvalidParameterKey(0))
}

pub fn parse_dictionary_missing_comma_test() {
  assert parser.parse_dictionary("a=1 b=2") == Error(CommaExpectedError(4))
}

pub fn serialize_dictionary_empty_test() {
  assert serializer.serialize_dictionary([]) == ""
}

pub fn serialize_dictionary_single_entry_test() {
  assert serializer.serialize_dictionary([#("a", Item(Integer(1), []))])
    == "a=1"
}

pub fn serialize_dictionary_multiple_entries_test() {
  assert serializer.serialize_dictionary([
      #("a", Item(Integer(1), [])),
      #("b", Item(Integer(2), [])),
    ])
    == "a=1, b=2"
}

pub fn serialize_dictionary_boolean_shorthand_test() {
  assert serializer.serialize_dictionary([#("flag", Item(Boolean(True), []))])
    == "flag"
}

pub fn serialize_dictionary_shorthand_with_params_test() {
  assert serializer.serialize_dictionary([
      #("flag", Item(Boolean(True), [Parameter("x", Integer(2))])),
    ])
    == "flag;x=2"
}

pub fn serialize_dictionary_entry_with_params_test() {
  assert serializer.serialize_dictionary([
      #("a", Item(Integer(1), [Parameter("x", Integer(2))])),
    ])
    == "a=1;x=2"
}

pub fn serialize_dictionary_inner_list_value_test() {
  assert serializer.serialize_dictionary([
      #("a", InnerList([Item(Integer(1), []), Item(Integer(2), [])], [])),
    ])
    == "a=(1 2)"
}
