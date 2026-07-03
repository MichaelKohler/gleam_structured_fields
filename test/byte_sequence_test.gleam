import structured_fields/errors.{InvalidByteSequence}
import structured_fields/parser
import structured_fields/serializer
import structured_fields/types.{ByteSequence, FieldList, Item}

pub fn parse_byte_sequence_basic_test() {
  assert parser.parse_list(":aGVsbG8=:")
    == Ok(FieldList([Item(ByteSequence(<<"hello">>), [])]))
}

pub fn parse_byte_sequence_empty_test() {
  assert parser.parse_list("::")
    == Ok(FieldList([Item(ByteSequence(<<>>), [])]))
}

pub fn parse_byte_sequence_no_padding_test() {
  assert parser.parse_list(":aGVsbG8:")
    == Ok(FieldList([Item(ByteSequence(<<"hello">>), [])]))
}

pub fn parse_byte_sequence_list_test() {
  assert parser.parse_list(":aGVsbG8=:, :d29ybGQ=:")
    == Ok(
      FieldList([
        Item(ByteSequence(<<"hello">>), []),
        Item(ByteSequence(<<"world">>), []),
      ]),
    )
}

pub fn parse_byte_sequence_unterminated_test() {
  assert parser.parse_list(":abc") == Error(InvalidByteSequence(4))
}

pub fn parse_byte_sequence_invalid_chars_test() {
  assert parser.parse_list(":!!!:") == Error(InvalidByteSequence(4))
}

pub fn serialize_byte_sequence_basic_test() {
  assert serializer.serialize_item(Item(ByteSequence(<<"hello">>), []))
    == ":aGVsbG8=:"
}

pub fn serialize_byte_sequence_empty_test() {
  assert serializer.serialize_item(Item(ByteSequence(<<>>), [])) == "::"
}

pub fn serialize_byte_sequence_list_test() {
  assert serializer.serialize_list(
      FieldList([
        Item(ByteSequence(<<"hello">>), []),
        Item(ByteSequence(<<"world">>), []),
      ]),
    )
    == ":aGVsbG8=:, :d29ybGQ=:"
}
