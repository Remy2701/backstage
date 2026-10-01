import gleam/dynamic
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option.{type Option}
import gleam/pair
import gleam/time/timestamp
import json_value
import openapi/openapi_type.{type OpenAPIType}

/// The error type returned when decoding fails.
pub type DecodeError =
  decode.DecodeError

/// A decoder for a specific type `t` that knows how to parse a dynamic value 
/// and contains the openapi specification of that type.
pub type Decoder(t) {
  Decoder(decoder: decode.Decoder(t), doc: fn() -> OpenAPIType)
}

/// A decoder for a Nil value.
pub fn nil() -> Decoder(Nil) {
  Decoder(decoder: decode.success(Nil), doc: fn() { openapi_type.Null })
}

/// A decoder for a string.
pub fn string() -> Decoder(String) {
  Decoder(decode.string, openapi_type.string)
}

/// A decoder for a string enum.
///
/// `first` is the first value of the enum, and `values` is the rest of the 
/// values. This is because it requires at least one value to be present.
pub fn string_enum(
  first: #(String, a),
  values: List(#(String, a)),
) -> Decoder(a) {
  Decoder(
    decoder: decode.then(decode.string, fn(value) {
      let found = list.key_find([first, ..values], value)

      case found {
        Ok(found) -> decode.success(found)
        Error(_) -> decode.failure(first.1, "Value not found in enum")
      }
    }),
    doc: fn() { openapi_type.string_enum(list.map(values, pair.first)) },
  )
}

/// A decoder for a boolean value.
pub fn bool() -> Decoder(Bool) {
  Decoder(decode.bool, openapi_type.boolean)
}

/// A decoder for an integer value.
pub fn int() -> Decoder(Int) {
  Decoder(decode.int, fn() {
    openapi_type.integer() |> openapi_type.format("int64")
  })
}

/// A decoder for a floating-point value. Note that it will also accept 
/// integers and convert them to floats.
pub fn float() -> Decoder(Float) {
  Decoder(
    decode.one_of(decode.float, [decode.map(decode.int, int.to_float)]),
    fn() { openapi_type.number() |> openapi_type.format("double") },
  )
}

/// A decoder for a list of values.
pub fn list(of inner: Decoder(t)) -> Decoder(List(t)) {
  Decoder(decode.list(inner.decoder), fn() { openapi_type.array(inner.doc()) })
}

/// A decoder for a list of values.
pub fn optional(of inner: Decoder(t)) -> Decoder(Option(t)) {
  Decoder(decode.optional(inner.decoder), fn() {
    openapi_type.option(inner.doc())
  })
}

/// A decoder for a timestamp formatted as a string using RFC3339
pub fn timestamp() -> Decoder(timestamp.Timestamp) {
  Decoder(
    decoder: decode.then(decode.string, fn(value) {
      case timestamp.parse_rfc3339(value) {
        Ok(value) -> decode.success(value)
        Error(_) ->
          decode.failure(timestamp.unix_epoch, "Failed to parse datetime")
      }
    }),
    doc: fn() { openapi_type.string() |> openapi_type.format("date-time") },
  )
}

/// A decoder for a JSON value.
pub fn json_value() -> Decoder(json_value.JsonValue) {
  Decoder(decoder: json_value.decoder(), doc: fn() { openapi_type.object([]) })
}

/// Runs a decoder on a dynamic value, returning either the decoded 
/// value or a list of errors.
pub fn run(
  value: dynamic.Dynamic,
  decoder: Decoder(t),
) -> Result(t, List(DecodeError)) {
  decode.run(value, decoder.decoder)
}

/// The decoder type for an object.
pub opaque type ObjectDecoder(a) {
  ObjectDecoder(
    builder: fn() -> decode.Decoder(a),
    doc: fn() -> openapi_type.OpenAPIType,
  )
}

/// A decoder for an empty object
pub fn empty_object() -> ObjectDecoder(Nil) {
  ObjectDecoder(builder: fn() { decode.success(Nil) }, doc: fn() {
    openapi_type.object([])
  })
}

/// A decoder for an object with a single or initial field with the given name and decoder.
pub fn object(name: String, decoder: Decoder(b)) -> ObjectDecoder(b) {
  ObjectDecoder(
    builder: fn() {
      use value <- decode.field(name, decoder.decoder)
      decode.success(value)
    },
    doc: fn() { openapi_type.object([#(name, decoder.doc())]) },
  )
}

/// Add a new field with the given name and decoder to an object decoder.
pub fn field(
  object object: ObjectDecoder(a),
  name name: String,
  decoder decoder: Decoder(b),
) -> ObjectDecoder(#(a, b)) {
  ObjectDecoder(
    builder: fn() {
      use value <- decode.field(name, decoder.decoder)
      object.builder()
      |> decode.map(fn(a) { #(a, value) })
    },
    doc: fn() {
      let doc = object.doc()
      case doc {
        openapi_type.Object(..) ->
          openapi_type.Object(
            ..doc,
            properties: list.append(doc.properties, [#(name, decoder.doc())]),
          )
        _ -> openapi_type.object([#(name, decoder.doc())])
      }
    },
  )
}

/// Construct a custom type from a ObjectDecoder
/// 
/// Usage:
/// ```gleam
/// decode.object("field_a", decode.string())
/// |> decode.field("field_b", decode.int())
/// |> decode.field("field_c", decode.bool())
/// |> decode.build(fn(data) {
///   let #(#(field_a, field_b), field_c) = data
///   
///   MyType(
///     field_a: field_a,
///     field_b: field_b,
///     field_c: field_c,
///   )
/// })
/// ```
pub fn build(object: ObjectDecoder(a), builder: fn(a) -> b) -> Decoder(b) {
  Decoder(decoder: decode.map(object.builder(), builder), doc: object.doc)
}
