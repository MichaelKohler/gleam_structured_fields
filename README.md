# structured_fields

[![Package Version](https://img.shields.io/hexpm/v/structured_fields)](https://hex.pm/packages/structured_fields)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/structured_fields/)

Implements parsing and serializing of [RFC 9651](https://www.rfc-editor.org/info/rfc9651/), with backwards compatibility to [RFC 8941](https://www.rfc-editor.org/info/rfc8941/).

## Usage

```sh
gleam add structured_fields
```

See the example in `example.gleam` and run:

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

* Implement Display String, Byte Sequence
* Implement Parameters
* Implement Dictionary ("ordered"!)
* Implement Inner List
* Verify that value is an ASCII string
* Implement Serializing
* Possible to tighten the return types of the parse functions?
* Add examples to README directly once working
* Publish hexdocs doc
