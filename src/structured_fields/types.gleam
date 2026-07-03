pub type Parameter {
  Parameter(name: String, value: BareItem)
}

pub type Element {
  Item(value: BareItem, parameters: List(Parameter))
  InnerList(value: List(Element), parameters: List(Parameter))
}

pub type BareItem {
  BareString(String)
  Boolean(Bool)
  ByteSequence(BitArray)
  Integer(Int)
  Decimal(Float)
  Token(String)
  DisplayString(String)
}
