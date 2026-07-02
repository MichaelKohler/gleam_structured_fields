pub type Parameter {
  Parameter(name: String, value: String)
}

pub type Element {
  Item(value: BareItem, parameters: List(Parameter))
  InnerList(value: List(Element), parameters: List(Parameter))
  FieldList(value: List(Element))
}

pub type BareItem {
  BareString(value: String)
  IntegerOrDecimal
  Boolean(Bool)
  Integer(Int)
  Decimal(Float)
}
