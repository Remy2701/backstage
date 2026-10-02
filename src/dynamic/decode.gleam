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

/// Extract a single value from the result of the ObjectDecoder. This function 
/// is only here for consistency
pub fn extract1(data: a) -> a {
  data
}

/// Extract a 2 value from the result of the ObjectDecoder. This function 
/// is only here for consistency
pub fn extract2(data: #(a, b)) -> #(a, b) {
  data
}

/// Extract a 3 value from the result of the ObjectDecoder. 
pub fn extract3(data: #(#(a, b), c)) -> #(a, b, c) {
  let #(#(a, b), c) = data
  #(a, b, c)
}

/// Extract a 4 value from the result of the ObjectDecoder. 
pub fn extract4(data: #(#(#(a, b), c), d)) -> #(a, b, c, d) {
  let #(#(#(a, b), c), d) = data
  #(a, b, c, d)
}

/// Extract a 5 value from the result of the ObjectDecoder. 
pub fn extract5(data: #(#(#(#(a, b), c), d), e)) -> #(a, b, c, d, e) {
  let #(#(#(#(a, b), c), d), e) = data
  #(a, b, c, d, e)
}

/// Extract a 6 value from the result of the ObjectDecoder. 
pub fn extract6(data: #(#(#(#(#(a, b), c), d), e), f)) -> #(a, b, c, d, e, f) {
  let #(#(#(#(#(a, b), c), d), e), f) = data
  #(a, b, c, d, e, f)
}

/// Extract a 7 value from the result of the ObjectDecoder. 
pub fn extract7(
  data: #(#(#(#(#(#(a, b), c), d), e), f), g),
) -> #(a, b, c, d, e, f, g) {
  let #(#(#(#(#(#(a, b), c), d), e), f), g) = data
  #(a, b, c, d, e, f, g)
}

/// Extract a 8 value from the result of the ObjectDecoder. 
pub fn extract8(
  data: #(#(#(#(#(#(#(a, b), c), d), e), f), g), h),
) -> #(a, b, c, d, e, f, g, h) {
  let #(#(#(#(#(#(#(a, b), c), d), e), f), g), h) = data
  #(a, b, c, d, e, f, g, h)
}

/// Extract a 9 value from the result of the ObjectDecoder. 
pub fn extract9(
  data: #(#(#(#(#(#(#(#(a, b), c), d), e), f), g), h), i),
) -> #(a, b, c, d, e, f, g, h, i) {
  let #(#(#(#(#(#(#(#(a, b), c), d), e), f), g), h), i) = data
  #(a, b, c, d, e, f, g, h, i)
}

/// Extract a 10 value from the result of the ObjectDecoder. 
pub fn extract10(
  data: #(#(#(#(#(#(#(#(#(a, b), c), d), e), f), g), h), i), j),
) -> #(a, b, c, d, e, f, g, h, i, j) {
  let #(#(#(#(#(#(#(#(#(a, b), c), d), e), f), g), h), i), j) = data
  #(a, b, c, d, e, f, g, h, i, j)
}

/// Extract a 11 value from the result of the ObjectDecoder. 
pub fn extract11(
  data: #(#(#(#(#(#(#(#(#(#(a, b), c), d), e), f), g), h), i), j), k),
) -> #(a, b, c, d, e, f, g, h, i, j, k) {
  let #(#(#(#(#(#(#(#(#(#(a, b), c), d), e), f), g), h), i), j), k) = data
  #(a, b, c, d, e, f, g, h, i, j, k)
}

/// Extract a 12 value from the result of the ObjectDecoder. 
pub fn extract12(
  data: #(#(#(#(#(#(#(#(#(#(#(a, b), c), d), e), f), g), h), i), j), k), l),
) -> #(a, b, c, d, e, f, g, h, i, j, k, l) {
  let #(#(#(#(#(#(#(#(#(#(#(a, b), c), d), e), f), g), h), i), j), k), l) = data
  #(a, b, c, d, e, f, g, h, i, j, k, l)
}
