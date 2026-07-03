import structured_fields/errors.{WrongDecimalOrIntegerInput}
import structured_fields/parser
import structured_fields/serializer
import structured_fields/types.{FieldList, Integer, Item}

pub fn parse_integer_positive_test() {
  assert parser.parse_list("42") == Ok(FieldList([Item(Integer(42), [])]))
}

pub fn parse_integer_negative_test() {
  assert parser.parse_list("-42") == Ok(FieldList([Item(Integer(-42), [])]))
}

pub fn parse_integer_zero_test() {
  assert parser.parse_list("0") == Ok(FieldList([Item(Integer(0), [])]))
}

pub fn parse_integer_max_test() {
  assert parser.parse_list("999999999999999")
    == Ok(FieldList([Item(Integer(999_999_999_999_999), [])]))
}

pub fn parse_integer_min_test() {
  assert parser.parse_list("-999999999999999")
    == Ok(FieldList([Item(Integer(-999_999_999_999_999), [])]))
}

pub fn parse_integer_too_many_digits_test() {
  assert parser.parse_list("9999999999999999")
    == Error(WrongDecimalOrIntegerInput(16))
}

pub fn serialize_integer_positive_test() {
  assert serializer.serialize_item(Item(Integer(42), [])) == "42"
}

pub fn serialize_integer_negative_test() {
  assert serializer.serialize_item(Item(Integer(-42), [])) == "-42"
}

pub fn serialize_integer_zero_test() {
  assert serializer.serialize_item(Item(Integer(0), [])) == "0"
}

pub fn serialize_integer_max_test() {
  assert serializer.serialize_item(Item(Integer(999_999_999_999_999), []))
    == "999999999999999"
}
