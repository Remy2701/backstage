import dynamic/spec.{type Spec}
import gleam/dict
import gleam/json.{type Json}
import gleam/list
import gleam/option.{type Option}
import gleam/pair
import gleam/time/calendar
import gleam/time/timestamp
import json_value.{type JsonValue}
import openapi/openapi_type.{type OpenAPIType}
import taffy/value.{type YamlValue as Yaml}

/// An encoder for a specific type 't' that knows how to convert it to a 
/// dynamic specification and contains the openapi specification of that type.
pub type Encoder(t) {
  Encoder(encoder: fn(t) -> Spec, doc: fn() -> OpenAPIType)
}

/// Add a default value to the openapi specification of the given encoder.
pub fn with_default(encoder: Encoder(a), default: Spec) -> Encoder(a) {
  Encoder(..encoder, doc: fn() {
    encoder.doc() |> openapi_type.default(default)
  })
}

/// An encoder for the `Nil` type.
pub fn nil() -> Encoder(Nil) {
  Encoder(encoder: fn(_) { spec.null() }, doc: fn() { openapi_type.Null })
}

/// An encoder for a string.
pub fn string() -> Encoder(String) {
  Encoder(spec.string, openapi_type.string)
}

/// An encoder for a string enum with the list of potential value and the 
/// function to convert the variant to a string.
pub fn string_enum(values: List(a), to_string: fn(a) -> String) -> Encoder(a) {
  Encoder(fn(value) { to_string(value) |> spec.string() }, fn() {
    openapi_type.string_enum(values |> list.map(to_string))
  })
}

/// An encoder for a boolean.
pub fn bool() -> Encoder(Bool) {
  Encoder(spec.boolean, openapi_type.boolean)
}

/// An encoder for an integer.
pub fn int() -> Encoder(Int) {
  Encoder(spec.integer, fn() {
    openapi_type.integer() |> openapi_type.format("int64")
  })
}

/// An encoder for a float.
pub fn float() -> Encoder(Float) {
  Encoder(spec.float, fn() {
    openapi_type.number() |> openapi_type.format("double")
  })
}

/// An encoder for a list of values.
pub fn list(of inner: Encoder(a)) -> Encoder(List(a)) {
  Encoder(spec.array_of(_, inner.encoder), fn() {
    openapi_type.array(inner.doc())
  })
}

/// An encoder for an optional value.
pub fn optional(of inner: Encoder(a)) -> Encoder(Option(a)) {
  Encoder(spec.nullable(_, inner.encoder), fn() {
    openapi_type.option(inner.doc())
  })
}

/// An encoder for a timestamp formatted as a string using RFC3339
pub fn timestamp() -> Encoder(timestamp.Timestamp) {
  Encoder(
    fn(timestamp) {
      spec.string(timestamp.to_rfc3339(timestamp, calendar.utc_offset))
    },
    fn() { openapi_type.string() |> openapi_type.format("date-time") },
  )
}

fn json_value_to_spec(value: JsonValue) -> Spec {
  case value {
    json_value.Null -> spec.Null
    json_value.String(value) -> spec.string(value)
    json_value.Int(value) -> spec.integer(value)
    json_value.Bool(value) -> spec.boolean(value)
    json_value.Float(value) -> spec.float(value)
    json_value.Array(values) -> spec.array_of(values, json_value_to_spec)
    json_value.Object(values) ->
      spec.object(
        dict.to_list(values) |> list.map(pair.map_second(_, json_value_to_spec)),
      )
  }
}

/// An encoder for a json_value.
pub fn json_value() -> Encoder(JsonValue) {
  Encoder(json_value_to_spec, fn() { openapi_type.object([]) })
}

/// The encoder type for a field within an object.
pub type FieldEncoder(a) =
  #(String, Encoder(a))

/// Create a field encoder for a specific field within an object.
pub fn field(
  name: String,
  getter: fn(a) -> b,
  of inner: Encoder(b),
) -> FieldEncoder(a) {
  #(
    name,
    Encoder(
      encoder: fn(object) { inner.encoder(getter(object)) },
      doc: inner.doc,
    ),
  )
}

/// An encoder for an object with the given field encoders.
pub fn object(encoders: List(FieldEncoder(a))) -> Encoder(a) {
  Encoder(
    fn(data) {
      spec.object(
        list.map(
          encoders,
          pair.map_second(_, fn(value) { value.encoder(data) }),
        ),
      )
    },
    fn() {
      openapi_type.object(
        list.map(encoders, pair.map_second(_, fn(value) { value.doc() })),
      )
    },
  )
}

/// Encode a value using the given encoder.
pub fn encode(a: a, of encoder: Encoder(a)) -> Spec {
  encoder.encoder(a)
}

/// Directly encode a value using the given encoder to JSON.
pub fn encode_json(a: a, of encoder: Encoder(a)) -> Json {
  spec.to_json(encode(a, of: encoder))
}

/// Directly encode a value using the given encoder to JSON.
pub fn encode_yaml(a: a, of encoder: Encoder(a)) -> Yaml {
  spec.to_yaml(encode(a, of: encoder))
}
