import structured_fields/errors.{WrongDecimalOrIntegerInput}
import structured_fields/parser
import structured_fields/types.{Decimal, FieldList, Item}

pub fn parse_decimal_positive_test() {
  assert parser.parse_list("3.14") == Ok(FieldList([Item(Decimal(3.14), [])]))
}

pub fn parse_decimal_negative_test() {
  assert parser.parse_list("-1.5") == Ok(FieldList([Item(Decimal(-1.5), [])]))
}

pub fn parse_decimal_zero_test() {
  assert parser.parse_list("0.0") == Ok(FieldList([Item(Decimal(0.0), [])]))
}

pub fn parse_decimal_three_fractional_digits_test() {
  assert parser.parse_list("1.123") == Ok(FieldList([Item(Decimal(1.123), [])]))
}

pub fn parse_decimal_too_many_fractional_digits_test() {
  assert parser.parse_list("1.1234") == Error(WrongDecimalOrIntegerInput(6))
}

pub fn parse_decimal_trailing_period_test() {
  assert parser.parse_list("1.") == Error(WrongDecimalOrIntegerInput(2))
}

pub fn parse_decimal_double_period_test() {
  assert parser.parse_list("1.2.3") == Error(WrongDecimalOrIntegerInput(3))
}
