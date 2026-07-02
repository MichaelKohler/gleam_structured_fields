import gleam/io
import gleam/string
import structured_fields/parser

pub fn main() {
  let value = "blu, meh"
  let parsed = parser.parse(value)

  case parsed {
    Ok(fields) -> {
      io.println(string.inspect(fields))
    }
    Error(e) -> {
      io.println("Error parsing structured fields")
      io.println(string.inspect(e))
    }
  }
}
