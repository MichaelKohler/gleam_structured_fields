import structured_fields/errors.{WrongDateFormat}
import structured_fields/parser
import structured_fields/serializer
import structured_fields/types.{FieldList, Integer, Item}

pub fn parse_date_positive_test() {
  assert parser.parse_list("@1686055940")
    == Ok(FieldList([Item(Integer(1_686_055_940), [])]))
}

pub fn parse_date_negative_test() {
  assert parser.parse_list("@-1686055940")
    == Ok(FieldList([Item(Integer(-1_686_055_940), [])]))
}

pub fn parse_date_zero_test() {
  assert parser.parse_list("@0") == Ok(FieldList([Item(Integer(0), [])]))
}

pub fn parse_date_decimal_rejected_test() {
  assert parser.parse_list("@1.5") == Error(WrongDateFormat(1))
}

// There is no Date variant in BareItem — the parser stores dates as Integer.
// Dates therefore serialize identically to integers without the "@" prefix.
pub fn serialize_date_as_integer_test() {
  assert serializer.serialize_item(Item(Integer(1_686_055_940), []))
    == "1686055940"
}
