import argv
import gleam/bit_array
import gleam/bool
import gleam/dict
import gleam/dynamic/decode
import gleam/float
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import simplifile
import thirtytwo

// ---------------------------------------------------------------------------
// JSON value representation
// ---------------------------------------------------------------------------

type JsonValue {
  JsonBool(Bool)
  JsonInt(Int)
  JsonFloat(Float)
  JsonString(String)
  JsonArray(List(JsonValue))
  JsonObject(List(#(String, JsonValue)))
}

fn json_value_decoder() -> decode.Decoder(JsonValue) {
  decode.one_of(decode.map(decode.bool, JsonBool), or: [
    decode.map(decode.int, JsonInt),
    decode.map(decode.float, JsonFloat),
    decode.map(decode.string, JsonString),
    decode.map(
      decode.list(decode.recursive(fn() { json_value_decoder() })),
      JsonArray,
    ),
    decode.map(
      decode.dict(
        decode.string,
        decode.recursive(fn() { json_value_decoder() }),
      ),
      fn(d) { JsonObject(dict.to_list(d)) },
    ),
  ])
}

// ---------------------------------------------------------------------------
// Test-case record
// ---------------------------------------------------------------------------

type TestCase {
  TestCase(
    name: String,
    raw: List(String),
    header_type: String,
    expected: Option(JsonValue),
    must_fail: Bool,
    can_fail: Bool,
  )
}

fn test_case_decoder() -> decode.Decoder(TestCase) {
  use name <- decode.field("name", decode.string)
  use raw <- decode.field("raw", decode.list(decode.string))
  use header_type <- decode.field("header_type", decode.string)
  use expected <- decode.optional_field(
    "expected",
    None,
    decode.map(json_value_decoder(), Some),
  )
  use must_fail <- decode.optional_field("must_fail", False, decode.bool)
  use can_fail <- decode.optional_field("can_fail", False, decode.bool)
  decode.success(TestCase(
    name: name,
    raw: raw,
    header_type: header_type,
    expected: expected,
    must_fail: must_fail,
    can_fail: can_fail,
  ))
}

// ---------------------------------------------------------------------------
// Name sanitisation (no regex dep)
// ---------------------------------------------------------------------------

fn is_word_char(c: String) -> Bool {
  case string.to_utf_codepoints(c) {
    [pt] -> {
      let n = string.utf_codepoint_to_int(pt)
      { n >= 97 && n <= 122 } || { n >= 48 && n <= 57 }
    }
    _ -> False
  }
}

fn sanitize_name(name: String) -> String {
  let chars = string.to_graphemes(string.lowercase(name))
  let with_underscores =
    list.fold(chars, "", fn(acc, c) {
      case is_word_char(c) {
        True -> acc <> c
        False ->
          case string.ends_with(acc, "_") || acc == "" {
            True -> acc
            False -> acc <> "_"
          }
      }
    })
  trim_leading_trailing_underscores(with_underscores)
}

fn trim_leading_trailing_underscores(s: String) -> String {
  case string.starts_with(s, "_") {
    True -> trim_leading_trailing_underscores(string.drop_start(s, 1))
    False ->
      case string.ends_with(s, "_") {
        True -> trim_leading_trailing_underscores(string.drop_end(s, 1))
        False -> s
      }
  }
}

fn file_stem_from(filename: String) -> String {
  filename
  |> string.replace(".json", "")
  |> string.replace("-", "_")
}

// ---------------------------------------------------------------------------
// Code generation helpers
// ---------------------------------------------------------------------------

fn escape_gleam_string(s: String) -> String {
  s
  |> string.replace("\\", "\\\\")
  |> string.replace("\"", "\\\"")
  |> string.replace("\n", "\\n")
  |> string.replace("\r", "\\r")
  |> string.replace("\t", "\\t")
}

fn bitarray_bytes(bits: BitArray) -> List(Int) {
  do_bitarray_bytes(bits, 0, bit_array.byte_size(bits), [])
}

fn do_bitarray_bytes(
  bits: BitArray,
  offset: Int,
  size: Int,
  acc: List(Int),
) -> List(Int) {
  use <- bool.guard(offset >= size, list.reverse(acc))
  let assert Ok(<<b:8>>) = bit_array.slice(bits, offset, 1)
  do_bitarray_bytes(bits, offset + 1, size, [b, ..acc])
}

fn bitarray_to_gleam_literal(bits: BitArray) -> String {
  let bytes = bitarray_bytes(bits)
  "<<" <> string.join(list.map(bytes, int.to_string), ", ") <> ">>"
}

fn find_field(
  fields: List(#(String, JsonValue)),
  key: String,
) -> Option(JsonValue) {
  list.find_map(fields, fn(pair) {
    let #(k, v) = pair
    case k == key {
      True -> Ok(v)
      False -> Error(Nil)
    }
  })
  |> option.from_result
}

fn bare_item_to_gleam(value: JsonValue) -> String {
  case value {
    JsonBool(True) -> "Boolean(True)"
    JsonBool(False) -> "Boolean(False)"
    JsonInt(n) -> "Integer(" <> int.to_string(n) <> ")"
    JsonFloat(f) -> "Decimal(" <> float.to_string(f) <> ")"
    JsonString(s) -> "BareString(\"" <> escape_gleam_string(s) <> "\")"
    JsonObject(fields) ->
      case find_field(fields, "__type") {
        Some(JsonString("token")) ->
          case find_field(fields, "value") {
            Some(JsonString(v)) -> "Token(\"" <> escape_gleam_string(v) <> "\")"
            _ -> "Token(\"\")"
          }
        Some(JsonString("binary")) ->
          case find_field(fields, "value") {
            Some(JsonString(encoded)) ->
              case thirtytwo.decode(encoded) {
                Ok(bits) ->
                  "ByteSequence(" <> bitarray_to_gleam_literal(bits) <> ")"
                Error(_) -> "ByteSequence(<<>>)"
              }
            _ -> "ByteSequence(<<>>)"
          }
        Some(JsonString("date")) ->
          case find_field(fields, "value") {
            Some(JsonInt(n)) -> "Integer(" <> int.to_string(n) <> ")"
            _ -> "Integer(0)"
          }
        Some(JsonString("displaystring")) ->
          case find_field(fields, "value") {
            Some(JsonString(v)) ->
              "DisplayString(\"" <> escape_gleam_string(v) <> "\")"
            _ -> "DisplayString(\"\")"
          }
        _ -> "Integer(0)"
      }
    _ -> "Integer(0)"
  }
}

fn params_to_gleam(params: JsonValue) -> String {
  case params {
    JsonArray([]) -> "[]"
    JsonArray(pairs) ->
      "["
      <> string.join(
        list.map(pairs, fn(pair) {
          case pair {
            JsonArray([JsonString(key), val]) ->
              "Parameter(\""
              <> escape_gleam_string(key)
              <> "\", "
              <> bare_item_to_gleam(val)
              <> ")"
            _ -> "Parameter(\"\", Integer(0))"
          }
        }),
        ", ",
      )
      <> "]"
    _ -> "[]"
  }
}

fn element_to_gleam(value: JsonValue) -> String {
  case value {
    JsonArray([JsonArray(inner_items), params]) ->
      "InnerList(["
      <> string.join(list.map(inner_items, element_to_gleam), ", ")
      <> "], "
      <> params_to_gleam(params)
      <> ")"
    JsonArray([bare, params]) ->
      "Item("
      <> bare_item_to_gleam(bare)
      <> ", "
      <> params_to_gleam(params)
      <> ")"
    _ -> "Item(Integer(0), [])"
  }
}

fn list_expected_to_gleam(expected: JsonValue) -> String {
  case expected {
    JsonArray(items) ->
      "[" <> string.join(list.map(items, element_to_gleam), ", ") <> "]"
    _ -> "[]"
  }
}

fn dict_expected_to_gleam(expected: JsonValue) -> String {
  case expected {
    JsonArray(pairs) ->
      "["
      <> string.join(
        list.map(pairs, fn(pair) {
          case pair {
            JsonArray([JsonString(key), val]) ->
              "#(\""
              <> escape_gleam_string(key)
              <> "\", "
              <> element_to_gleam(val)
              <> ")"
            _ -> "#(\"\", Item(Integer(0), []))"
          }
        }),
        ", ",
      )
      <> "]"
    _ -> "[]"
  }
}

fn item_expected_to_gleam(expected: JsonValue) -> String {
  case expected {
    JsonArray([bare, params]) ->
      "#(" <> bare_item_to_gleam(bare) <> ", " <> params_to_gleam(params) <> ")"
    _ -> "#(Integer(0), [])"
  }
}

fn parse_fn_name(header_type: String) -> String {
  case header_type {
    "list" -> "parser.parse_list"
    "dictionary" -> "parser.parse_dictionary"
    _ -> "parser.parse_item"
  }
}

fn expected_to_gleam(header_type: String, expected: JsonValue) -> String {
  case header_type {
    "list" -> "Ok(" <> list_expected_to_gleam(expected) <> ")"
    "dictionary" -> "Ok(" <> dict_expected_to_gleam(expected) <> ")"
    _ -> "Ok(" <> item_expected_to_gleam(expected) <> ")"
  }
}

fn generate_test_fn(
  prefix: String,
  dedup_index: Int,
  tc: TestCase,
) -> Option(String) {
  use <- bool.guard(tc.can_fail, None)
  let raw = escape_gleam_string(string.join(tc.raw, ", "))
  let suffix = case dedup_index {
    0 -> ""
    n -> "_" <> int.to_string(n + 1)
  }
  let fn_name = prefix <> "_" <> sanitize_name(tc.name) <> suffix <> "_test"
  let parse_call = parse_fn_name(tc.header_type) <> "(\"" <> raw <> "\")"
  case tc.must_fail, tc.expected {
    True, _ ->
      Some(
        "pub fn "
        <> fn_name
        <> "() {\n  assert result.is_error("
        <> parse_call
        <> ")\n}",
      )
    False, Some(expected) ->
      Some(
        "pub fn "
        <> fn_name
        <> "() {\n  assert "
        <> parse_call
        <> " == "
        <> expected_to_gleam(tc.header_type, expected)
        <> "\n}",
      )
    False, None -> None
  }
}

// ---------------------------------------------------------------------------
// Deduplication of sanitized names within a file
// ---------------------------------------------------------------------------

fn with_dedup_indices(cases: List(TestCase)) -> List(#(Int, TestCase)) {
  let #(indexed, _) =
    list.fold(cases, #([], dict.new()), fn(acc, tc) {
      let #(out, seen) = acc
      let key = sanitize_name(tc.name)
      let idx = dict.get(seen, key) |> result.unwrap(0)
      #(list.append(out, [#(idx, tc)]), dict.insert(seen, key, idx + 1))
    })
  indexed
}

// ---------------------------------------------------------------------------
// Per-file processing
// ---------------------------------------------------------------------------

fn file_header() -> String {
  "// Auto-generated from https://github.com/httpwg/structured-field-tests
// Do not edit manually — run: gleam run --directory scripts -- <test-repo-path>

import gleam/result
import structured_fields/parser
import structured_fields/types.{
  BareString, Boolean, ByteSequence, Decimal, DisplayString, Integer, InnerList,
  Item, Parameter, Token,
}
"
}

fn process_file(
  json_path: String,
  output_dir: String,
  stem: String,
) -> Result(Int, String) {
  use content <- result.try(
    simplifile.read(json_path)
    |> result.map_error(fn(e) {
      "Failed to read " <> json_path <> ": " <> string.inspect(e)
    }),
  )
  use cases <- result.try(
    json.parse(content, decode.list(test_case_decoder()))
    |> result.map_error(fn(e) {
      "Failed to parse " <> json_path <> ": " <> string.inspect(e)
    }),
  )
  let prefix = "httpwg_" <> stem
  let fns =
    cases
    |> with_dedup_indices
    |> list.flat_map(fn(pair) {
      let #(idx, tc) = pair
      case generate_test_fn(prefix, idx, tc) {
        None -> []
        Some(fn_code) -> [fn_code]
      }
    })
  let out_path = output_dir <> "/" <> prefix <> "_test.gleam"
  let out_content = file_header() <> "\n" <> string.join(fns, "\n\n") <> "\n"
  use _ <- result.try(
    simplifile.write(out_path, out_content)
    |> result.map_error(fn(e) {
      "Failed to write " <> out_path <> ": " <> string.inspect(e)
    }),
  )
  Ok(list.length(fns))
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

pub fn main() {
  let args = argv.load().arguments
  let #(test_repo_path, output_dir) = case args {
    [repo] -> #(repo, "../test/httpwg")
    [repo, out] -> #(repo, out)
    _ -> panic as "Usage: gleam run -- <test-repo-path> [output-dir]"
  }

  let _ = simplifile.create_directory_all(output_dir)

  let json_files = case simplifile.read_directory(test_repo_path) {
    Ok(entries) ->
      entries
      |> list.filter(fn(name) { string.ends_with(name, ".json") })
      |> list.sort(string.compare)
    Error(e) -> panic as { "Cannot read test repo: " <> string.inspect(e) }
  }

  let total =
    list.fold(json_files, 0, fn(count, filename) {
      let stem = file_stem_from(filename)
      let path = test_repo_path <> "/" <> filename
      case process_file(path, output_dir, stem) {
        Ok(n) -> {
          io.println("  " <> int.to_string(n) <> " tests  ← " <> filename)
          count + n
        }
        Error(msg) -> {
          io.println("  WARNING: " <> msg)
          count
        }
      }
    })

  io.println(
    "Generated "
    <> int.to_string(total)
    <> " test functions in "
    <> output_dir
    <> "/",
  )
}
