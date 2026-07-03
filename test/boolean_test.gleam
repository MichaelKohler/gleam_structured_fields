import structured_fields/errors.{InvalidBoolean}
import structured_fields/parser
import structured_fields/serializer
import structured_fields/types.{Boolean, Item}

pub fn parse_boolean_true_test() {
  assert parser.parse_list("?1") == Ok([Item(Boolean(True), [])])
}

pub fn parse_boolean_false_test() {
  assert parser.parse_list("?0") == Ok([Item(Boolean(False), [])])
}

pub fn parse_boolean_invalid_test() {
  assert parser.parse_list("?2") == Error(InvalidBoolean(1))
}

pub fn parse_boolean_missing_value_test() {
  assert parser.parse_list("?") == Error(InvalidBoolean(1))
}

pub fn serialize_boolean_true_test() {
  assert serializer.serialize_item(Item(Boolean(True), [])) == "?1"
}

pub fn serialize_boolean_false_test() {
  assert serializer.serialize_item(Item(Boolean(False), [])) == "?0"
}
