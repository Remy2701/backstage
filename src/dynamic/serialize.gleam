import dynamic/spec.{type Spec}
import gleam/dict
import gleam/dynamic
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option.{type Option}
import gleam/pair
import gleam/result
import gleam/time/calendar
import gleam/time/timestamp.{type Timestamp}
import json_value.{type JsonValue}
import openapi/openapi_type.{type OpenAPIType}

/// An encoder for a specific type `t` that knows how to encode a value into a 
/// dynamic spec and contains the openapi specification of that type.
pub type Encoder(t) {
  Encoder(encoder: fn(t) -> Spec, doc: fn() -> OpenAPIType)
}

/// A decoder for a specific type `t` that knows how to parse a dynamic value 
/// and contains the openapi specification of that type.
pub type Decoder(t) {
  Decoder(decoder: decode.Decoder(t), doc: fn() -> OpenAPIType)
}

/// A serializer that allows encoding and decoding values
pub type Serializer(t) {
  Serializer(
    decoder: decode.Decoder(t),
    encoder: fn(t) -> Spec,
    doc: fn() -> OpenAPIType,
  )
}

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                          Primitives                                           //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

/// A serializer for the `Nil` type.
pub fn nil() -> Serializer(Nil) {
  Serializer(
    decoder: decode.success(Nil),
    encoder: fn(_) { spec.null() },
    doc: fn() { openapi_type.Null },
  )
}

/// A serializer for the `String` type
pub fn string() -> Serializer(String) {
  Serializer(
    decoder: decode.string,
    encoder: spec.string,
    doc: openapi_type.string,
  )
}

pub fn bool() -> Serializer(Bool) {
  Serializer(
    decoder: decode.bool,
    encoder: spec.boolean,
    doc: openapi_type.boolean,
  )
}

pub fn int() -> Serializer(Int) {
  Serializer(
    decoder: decode.int,
    encoder: spec.integer,
    doc: openapi_type.integer,
  )
}

pub fn float() -> Serializer(Float) {
  Serializer(
    decoder: decode.one_of(decode.float, [decode.map(decode.int, int.to_float)]),
    encoder: spec.float,
    doc: fn() { openapi_type.number() |> openapi_type.format("double") },
  )
}

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                             List                                              //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

fn list_doc(of inner: fn() -> OpenAPIType) -> fn() -> OpenAPIType {
  fn() { openapi_type.array(inner()) }
}

pub fn list_decoder(of inner: Decoder(t)) -> Decoder(List(t)) {
  Decoder(decoder: decode.list(inner.decoder), doc: list_doc(inner.doc))
}

pub fn list_encoder(of inner: Encoder(t)) -> Encoder(List(t)) {
  Encoder(encoder: spec.array_of(_, inner.encoder), doc: list_doc(inner.doc))
}

pub fn list(of inner: Serializer(t)) -> Serializer(List(t)) {
  Serializer(
    decoder: list_decoder(decoder(inner)).decoder,
    encoder: list_encoder(encoder(inner)).encoder,
    doc: list_doc(inner.doc),
  )
}

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                           Optional                                            //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

fn optional_doc(of inner: fn() -> OpenAPIType) -> fn() -> OpenAPIType {
  fn() { openapi_type.option(inner()) }
}

pub fn optional_decoder(of inner: Decoder(t)) -> Decoder(Option(t)) {
  Decoder(decoder: decode.optional(inner.decoder), doc: optional_doc(inner.doc))
}

pub fn optional_encoder(of inner: Encoder(t)) -> Encoder(Option(t)) {
  Encoder(
    encoder: spec.nullable(_, inner.encoder),
    doc: optional_doc(inner.doc),
  )
}

pub fn optional(of inner: Serializer(t)) -> Serializer(Option(t)) {
  Serializer(
    decoder: optional_decoder(decoder(inner)).decoder,
    encoder: optional_encoder(encoder(inner)).encoder,
    doc: optional_doc(inner.doc),
  )
}

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                             Enum                                              //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

pub fn string_enum(
  values: List(a),
  to_string: fn(a) -> String,
) -> Serializer(a) {
  let assert [first, ..] = values
  Serializer(
    decoder: decode.then(decode.string, fn(value) {
      let found =
        values
        |> list.map(fn(value) { #(to_string(value), value) })
        |> list.key_find(value)

      case found {
        Ok(found) -> decode.success(found)
        Error(_) -> decode.failure(first, "Value not in enum")
      }
    }),
    encoder: fn(value) { value |> to_string |> spec.string },
    doc: fn() { openapi_type.string_enum(values |> list.map(to_string)) },
  )
}

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                           Timestamp                                           //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

pub fn timestamp() -> Serializer(Timestamp) {
  Serializer(
    decoder: decode.then(decode.string, fn(value) {
      case timestamp.parse_rfc3339(value) {
        Ok(value) -> decode.success(value)
        Error(_) ->
          decode.failure(timestamp.unix_epoch, "Failed to parse datetime")
      }
    }),
    encoder: fn(timestamp) {
      spec.string(timestamp.to_rfc3339(timestamp, calendar.utc_offset))
    },
    doc: fn() { openapi_type.string() |> openapi_type.format("date-time") },
  )
}

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                          JSON Value                                           //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

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

pub fn json_value() -> Serializer(JsonValue) {
  Serializer(
    decoder: json_value.decoder(),
    encoder: json_value_to_spec,
    doc: fn() { openapi_type.object([]) },
  )
}

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                        Object & Fields                                        //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

pub type FieldEncoder(a) =
  #(String, Encoder(a))

pub type Context(t) {
  Context(doc: fn() -> OpenAPIType, encoders: List(FieldEncoder(t)))
}

pub fn empty_object() -> Serializer(Nil) {
  object(build(_, Nil))
}

pub fn object(
  next: fn(Context(t)) -> decode.Decoder(#(Context(t), t)),
) -> Serializer(t) {
  let result =
    next(Context(doc: fn() { openapi_type.object([]) }, encoders: []))
  Serializer(
    decoder: decode.map(result, pair.second),
    encoder: fn(data) {
      let encoders =
        decode.run(dynamic.nil(), decode.map_errors(result, fn(_) { [] }))
        |> result.map(fn(value) { value.0.encoders })
        |> result.unwrap([])

      spec.object(
        encoders
        |> list.reverse
        |> list.map(pair.map_second(_, fn(value) { value.encoder(data) })),
      )
    },
    doc: fn() {
      decode.run(dynamic.nil(), decode.map_errors(result, fn(_) { [] }))
      |> result.map(fn(value) { value.0.doc() })
      |> result.unwrap(openapi_type.object([]))
    },
  )
}

pub fn field(
  context context: Context(final),
  name name: String,
  serializer serializer: Serializer(t),
  getter getter: fn(final) -> t,
  next next: fn(Context(final), t) -> decode.Decoder(#(Context(final), final)),
) -> decode.Decoder(#(Context(final), final)) {
  use value <- decode.field(name, serializer.decoder)

  next(
    Context(
      doc: fn() {
        let doc = context.doc()
        case doc {
          openapi_type.Object(..) ->
            openapi_type.Object(
              ..doc,
              properties: list.append(doc.properties, [
                #(name, serializer.doc()),
              ]),
            )
          _ -> openapi_type.object([#(name, serializer.doc())])
        }
      },
      encoders: [
        #(
          name,
          Encoder(
            encoder: fn(object) { serializer.encoder(getter(object)) },
            doc: serializer.doc,
          ),
        ),
        ..context.encoders
      ],
    ),
    value,
  )
}

pub fn optional_field(
  context context: Context(final),
  name name: String,
  default default: t,
  serializer serializer: Serializer(t),
  getter getter: fn(final) -> t,
  next next: fn(Context(final), t) -> decode.Decoder(#(Context(final), final)),
) -> decode.Decoder(#(Context(final), final)) {
  use value <- decode.optional_field(name, default, serializer.decoder)

  next(
    Context(
      doc: fn() {
        let doc = context.doc()
        case doc {
          openapi_type.Object(..) ->
            openapi_type.Object(
              ..doc,
              properties: list.append(doc.properties, [
                #(name, serializer.doc()),
              ]),
            )
          _ -> openapi_type.object([#(name, serializer.doc())])
        }
      },
      encoders: [
        #(
          name,
          Encoder(
            encoder: fn(object) { serializer.encoder(getter(object)) },
            doc: serializer.doc,
          ),
        ),
        ..context.encoders
      ],
    ),
    value,
  )
}

pub fn build(
  context: Context(t),
  value: t,
) -> decode.Decoder(#(Context(t), t)) {
  decode.success(#(context, value))
}

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                       Encoder & Decoder                                       //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

pub fn decoder(serializer: Serializer(t)) -> Decoder(t) {
  Decoder(decoder: serializer.decoder, doc: serializer.doc)
}

pub fn success(value: t) -> decode.Decoder(t) {
  decode.success(value)
}

pub fn encoder(serializer: Serializer(t)) -> Encoder(t) {
  Encoder(encoder: serializer.encoder, doc: serializer.doc)
}

pub fn decode(
  value: dynamic.Dynamic,
  serializer: Serializer(t),
) -> Result(t, List(decode.DecodeError)) {
  decode.run(value, serializer.decoder)
}

pub fn encode(value: t, serializer: Serializer(t)) -> spec.Spec {
  serializer.encoder(value)
}

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                       Doc Modifications                                       //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

/// Add a default value to the openapi specification of the given serializer.
pub fn with_default(serializer: Serializer(a), default: Spec) -> Serializer(a) {
  Serializer(..serializer, doc: fn() {
    serializer.doc() |> openapi_type.default(default)
  })
}

/// Add an example to the openapi specification of the given serializer.
pub fn with_example(serializer: Serializer(a), example: Spec) -> Serializer(a) {
  Serializer(..serializer, doc: fn() {
    serializer.doc() |> openapi_type.example(example)
  })
}

/// Add a pattern to the openapi specification of the given serializer.
pub fn with_pattern(
  serializer: Serializer(a),
  pattern: String,
) -> Serializer(a) {
  Serializer(..serializer, doc: fn() {
    serializer.doc() |> openapi_type.pattern(pattern)
  })
}
