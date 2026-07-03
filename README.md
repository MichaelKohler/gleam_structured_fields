# structured_fields

[![Package Version](https://img.shields.io/hexpm/v/structured_fields)](https://hex.pm/packages/structured_fields)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/structured_fields/)

Implements parsing and serializing of [RFC 9651](https://www.rfc-editor.org/info/rfc9651/), with backwards compatibility to [RFC 8941](https://www.rfc-editor.org/info/rfc8941/).

## Usage

```sh
gleam add structured_fields
```

```gleam
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
```

or run:

```sh
gleam run -m example
```

Further documentation can be found at <https://hexdocs.pm/structured_fields>.

## Development

```sh
gleam run   # Run the project
gleam test  # Run the tests
```

## Todo

* Publish hexdocs doc
* Implement https://github.com/httpwg/structured-field-tests/ tests
