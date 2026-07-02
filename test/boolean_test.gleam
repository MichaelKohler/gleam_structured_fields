import structured_fields/errors.{InvalidBoolean}
import structured_fields/parser
import structured_fields/types.{Boolean, FieldList, Item}

pub fn parse_boolean_true_test() {
  assert parser.parse_list("?1") == Ok(FieldList([Item(Boolean(True), [])]))
}

pub fn parse_boolean_false_test() {
  assert parser.parse_list("?0") == Ok(FieldList([Item(Boolean(False), [])]))
}

pub fn parse_boolean_invalid_test() {
  assert parser.parse_list("?2") == Error(InvalidBoolean(1))
}

pub fn parse_boolean_missing_value_test() {
  assert parser.parse_list("?") == Error(InvalidBoolean(1))
}
