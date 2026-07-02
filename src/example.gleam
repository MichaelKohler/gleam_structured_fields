import gleam/io
import gleam/string
import structured_fields/parser

pub fn main() {
  let value = "%\"This is intended for display to %c3%bcsers.\""
  let parsed = parser.parse_list(value)

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
