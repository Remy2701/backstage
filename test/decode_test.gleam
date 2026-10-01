import dynamic/decode
import gleam/dynamic
import gleam/list
import gleam/option
import openapi/openapi
import openapi/openapi_type

/// Test decoding of a string value.
pub fn decode_string_test() {
  let decoder = decode.string()

  let assert openapi_type.String(..) = decoder.doc()

  let assert Ok("test") = decode.run(dynamic.string("test"), decoder)
}

/// Test decoding of an integer value.
pub fn decode_int_test() {
  let decoder = decode.int()

  let assert openapi_type.Integer(..) = decoder.doc()

  let assert Ok(51) = decode.run(dynamic.int(51), decoder)
}

/// Test decoding of a float value.
pub fn decode_float_test() {
  let decoder = decode.float()

  let assert openapi_type.Number(..) = decoder.doc()

  let assert Ok(51.0) = decode.run(dynamic.float(51.0), decoder)
  let assert Ok(51.0) = decode.run(dynamic.int(51), decoder)
}

/// Test decoding of a boolean value.
pub fn decode_bool_test() {
  let decoder = decode.bool()

  let assert openapi_type.Boolean(..) = decoder.doc()

  let assert Ok(False) = decode.run(dynamic.bool(False), decoder)
  let assert Ok(True) = decode.run(dynamic.bool(True), decoder)
}

/// Test decoding of a list of strings.
pub fn decode_string_list_test() {
  let decoder = decode.list(decode.string())

  let assert openapi_type.Array(items: option.Some(openapi_type.String(..)), ..) =
    decoder.doc()

  let assert Ok(["a", "b", "c"]) =
    decode.run(
      dynamic.list(["a", "b", "c"] |> list.map(dynamic.string)),
      decoder,
    )
}

/// Test decoding of an object with string, integer, and boolean fields.
pub fn decode_object_test() {
  let decoder =
    decode.object("a", decode.string())
    |> decode.field("b", decode.int())
    |> decode.field("c", decode.bool())
    |> decode.build(fn(data) {
      let #(#(a, b), c) = data
      #(a, b, c)
    })

  let assert openapi_type.Object(
    properties: [
      #("a", openapi_type.String(..)),
      #("b", openapi_type.Integer(..)),
      #("c", openapi_type.Boolean(..)),
    ],
    ..,
  ) = decoder.doc()

  let assert openapi.Schema(
    type_: ["object"],
    properties: [
      #("a", openapi.Schema(type_: ["string"], ..)),
      #("b", openapi.Schema(type_: ["integer"], ..)),
      #("c", openapi.Schema(type_: ["boolean"], ..)),
    ],
    ..,
  ) = openapi_type.to_schema(decoder.doc())

  let assert Ok(#("Hello", 4, False)) =
    decode.run(
      dynamic.properties([
        #(dynamic.string("a"), dynamic.string("Hello")),
        #(dynamic.string("b"), dynamic.int(4)),
        #(dynamic.string("c"), dynamic.bool(False)),
      ]),
      decoder,
    )
}
