import dynamic/serialize
import dynamic/spec
import file_streams/file_stream
import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/result
import openapi/openapi_type
import wisp

pub fn json_string_of(
  inner: serialize.Serializer(a),
) -> serialize.Serializer(a) {
  serialize.Serializer(
    decoder: decode.then(decode.string, fn(value) {
      case json.parse(value, inner.decoder) {
        Ok(value) -> decode.success(value)
        Error(_) ->
          inner.decoder
          |> decode.map_errors(fn(errors) {
            case errors {
              [] -> []
              [first, ..] -> [
                decode.DecodeError(
                  ..first,
                  found: "Failed to parse JSON",
                  expected: "JSON",
                ),
              ]
            }
          })
      }
    }),
    encoder: inner.encoder,
    doc: inner.doc,
  )
}

pub fn raw_uploaded_file() -> serialize.Serializer(wisp.UploadedFile) {
  serialize.Serializer(
    ..serialize.object(fn(context) {
      use context, file_name <- serialize.field(
        context,
        "file_name",
        serialize.string(),
        fn(value: wisp.UploadedFile) { value.file_name },
      )
      use context, path <- serialize.field(
        context,
        "path",
        serialize.string(),
        fn(value: wisp.UploadedFile) { value.path },
      )

      serialize.build(context, wisp.UploadedFile(file_name:, path:))
    }),
    doc: fn() { openapi_type.string() |> openapi_type.format("binary") },
  )
}

fn bit_array_to_list(bits: BitArray) -> List(Int) {
  do_bit_array_to_list(bits, [])
}

fn do_bit_array_to_list(bits: BitArray, acc: List(Int)) -> List(Int) {
  case bits {
    // Match the first 8-bit integer, and capture the rest of the bits
    <<first:int, rest:bits>> -> do_bit_array_to_list(rest, [first, ..acc])
    // When no more bits are left, reverse the accumulator to restore original order
    _ -> list.reverse(acc)
  }
}

pub fn uploaded_file() {
  let serializer = raw_uploaded_file()
  serialize.Serializer(
    decoder: decode.then(
      decode.map_errors(serializer.decoder, fn(e) {
        case e {
          [] -> []
          _ -> [decode.DecodeError("wisp.UploadedFile", "Not a file", [])]
        }
      }),
      fn(file) {
        let result = {
          use stream <- result.try(
            file_stream.open_read(file.path)
            |> result.replace_error(
              decode.DecodeError("wisp.UploadedFile", "Failed to open file", []),
            ),
          )

          file_stream.read_remaining_bytes(stream)
          |> result.replace_error(
            decode.DecodeError("wisp.UploadedFile", "Failed to read file", []),
          )
        }
        case result {
          Ok(data) -> decode.success(data)
          Error(e) -> {
            decode.success(<<>>)
            |> decode.map_errors(fn(_) { [e] })
          }
        }
      },
    ),
    encoder: fn(data) { spec.array_of(bit_array_to_list(data), spec.integer) },
    doc: serializer.doc,
  )
}
