import dynamic/encode
import dynamic/serialize
import dynamic/spec
import gleam/bit_array
import gleam/bool
import gleam/dict
import gleam/dynamic
import gleam/dynamic/decode
import gleam/function
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/json
import gleam/list
import gleam/option
import gleam/pair
import gleam/result
import gleam/string
import mist
import openapi/openapi.{type OpenAPI}
import openapi/openapi_type
import wisp

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                             Scope                                             //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

pub opaque type OpenAPIScope {
  OpenAPIScope(doc: OpenAPI, method: http.Method, route: String)
}

/// Create a new OpenAPIScope using the given OpenAPI doc, http method and route path.
pub fn create_scope(
  doc doc: OpenAPI,
  method method: http.Method,
  route route: String,
) -> OpenAPIScope {
  OpenAPIScope(doc: doc, method: method, route: route)
}

/// Modify the OpenAPI document in the given [scope]
pub fn modify_doc(
  scope: OpenAPIScope,
  fun: fn(OpenAPI) -> OpenAPI,
) -> OpenAPIScope {
  OpenAPIScope(..scope, doc: fun(scope.doc))
}

/// Modify the OpenAPI operation in the given [scope]
pub fn modify_operation(
  scope: OpenAPIScope,
  fun: fn(openapi.Operation) -> openapi.Operation,
) -> OpenAPIScope {
  OpenAPIScope(
    ..scope,
    doc: scope.doc
      |> openapi.on_path(scope.route, fn(path) {
        case scope.method {
          http.Get -> openapi.path.get(path, fun)
          http.Post -> openapi.path.post(path, fun)
          http.Put -> openapi.path.put(path, fun)
          http.Delete -> openapi.path.delete(path, fun)
          http.Patch -> path
          http.Head -> path
          http.Options -> path
          http.Trace -> path
          http.Connect -> path
          http.Other(_) -> path
        }
      }),
  )
}

/// Get the OpenAPI document from the given [scope]
pub fn openapi_scope_doc(scope: OpenAPIScope) -> OpenAPI {
  scope.doc
}

pub fn openapi_scope_path(scope: OpenAPIScope) -> String {
  scope.route
}

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                          Route Spec                                           //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

pub type RouteSpecBuilder {
  RouteSpecBuilder(doc: fn(OpenAPI) -> OpenAPIScope)
}

pub fn modify_spec(
  spec: RouteSpecBuilder,
  transform: fn(OpenAPIScope) -> OpenAPIScope,
) -> RouteSpecBuilder {
  RouteSpecBuilder(doc: fn(doc) { doc |> spec.doc() |> transform() })
}

pub type RouteSpec(data) {
  RouteSpec(
    doc: fn(OpenAPI) -> OpenAPIScope,
    build: fn(Request) -> Result(data, WispResponse),
  )
}

pub type RouteCapability(data, object) {
  RouteCapability(
    get: fn(Request, fn(data) -> Result(object, WispResponse)) ->
      Result(object, WispResponse),
  )
}

pub fn capability(
  get: fn(Request) -> Result(data, WispResponse),
) -> RouteCapability(data, object) {
  RouteCapability(
    get: fn(request, next: fn(data) -> Result(object, WispResponse)) {
      result.try(get(request), next)
    },
  )
}

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                   Route Callback - Response                                   //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

/// Add a JSON response with the given encoder to the route
pub fn json_response_internal(
  spec: RouteSpecBuilder,
  code: Int,
  encoder: encode.Encoder(response),
  summary: String,
  response: fn(fn(response) -> WispResponse) -> data,
  next: fn(RouteSpecBuilder, RouteCapability(data, object)) -> RouteSpec(object),
) -> RouteSpec(object) {
  spec
  |> modify_spec(fn(scope) {
    scope
    |> modify_operation(fn(operation) {
      operation
      |> openapi.operation.response(code, fn(response) {
        response
        |> openapi.response.description(summary)
        |> openapi.response.content("application/json", fn(media) {
          media
          |> openapi.media_type.schema("", fn(_) {
            encoder.doc() |> openapi_type.to_schema()
          })
        })
      })
    })
  })
  |> next(
    capability(fn(_) {
      response(fn(response) {
        wisp.response(code)
        |> json_body(encode.encode_json(response, encoder))
      })
      |> Ok()
    }),
  )
}

//-----------------------------------------------------------------------------------------------//
//                                            Request                                            //
//-----------------------------------------------------------------------------------------------//

/// The common request type that supports both Wisp and Mist.
pub type Request =
  request.Request(Connection)

/// The generic connection type for both mist and wisp connections.
pub type Connection {
  MistConnection(mist.Connection)
  WispConnection(wisp.Connection)
}

//-----------------------------------------------------------------------------------------------//
//                                        Response (Mist)                                        //
//-----------------------------------------------------------------------------------------------//

/// The response type for Mist.
pub type MistResponse {
  MistResponse(response.Response(mist.ResponseData))
}

/// Converts a MistResponse to a WispResponse.
/// Note: currently only Bytes reponses are supported.
pub fn mist_response_to_wisp(response: MistResponse) -> WispResponse {
  let MistResponse(response) = response
  wisp.response(response.status)
  |> wisp.set_body(case response.body {
    mist.Websocket -> wisp.Text("Unsupported Websocket Response")
    mist.Bytes(bytes) -> wisp.Bytes(bytes)
    mist.Chunked -> wisp.Text("Unsupported Chunked Response")
    mist.File(..) -> wisp.Text("Unsupported File Response")
    mist.ServerSentEvents ->
      wisp.Text("Unsupported Server Sent Events Response")
  })
}

//-----------------------------------------------------------------------------------------------//
//                                          Wisp (Mist)                                          //
//-----------------------------------------------------------------------------------------------//

/// The response type for Wisp.
pub type WispResponse =
  wisp.Response

/// Set the given text to the body of the response, setting the content-type to text/plain
pub fn text_body(response: WispResponse, text: String) -> WispResponse {
  wisp.set_body(response, wisp.Text(text))
}

/// Set the given JSON to the body of the response, setting the content-type to application/json
pub fn json_body(response: WispResponse, json: json.Json) -> WispResponse {
  wisp.json_body(response, json.to_string(json))
}

pub type ErrorResponse {
  ErrorResponse(status: String, reason: String)
}

pub fn error_response_serializer(
  status: option.Option(String),
) -> serialize.Serializer(ErrorResponse) {
  serialize.object(fn(context) {
    use context, status <- serialize.field(
      context,
      "status",
      serialize.string()
        |> case status {
          option.Some(status) -> serialize.with_default(_, spec.string(status))
          option.None -> function.identity
        },
      fn(object: ErrorResponse) { object.status },
    )
    use context, reason <- serialize.field(
      context,
      "reason",
      serialize.string(),
      fn(object: ErrorResponse) { object.reason },
    )

    serialize.build(context, ErrorResponse(status:, reason:))
  })
}

pub type StatusCode {
  StatusCode(
    bad_request: Int,
    unauthorized: Int,
    not_found: Int,
    conflict: Int,
    internal_server_error: Int,
    service_unavailable: Int,
    timeout: Int,
    ok: Int,
    created: Int,
  )
}

pub const status_code: StatusCode = StatusCode(
  bad_request: 400,
  unauthorized: 401,
  not_found: 404,
  conflict: 409,
  internal_server_error: 500,
  service_unavailable: 503,
  timeout: 504,
  ok: 200,
  created: 201,
)

/// Return a 400 Bad Request response with the given message.
pub fn bad_request(message: String) -> WispResponse {
  wisp.response(status_code.bad_request)
  |> json_body(
    json.object([
      #("status", json.string("bad_request")),
      #("reason", json.string(message)),
    ]),
  )
}

/// Return a 401 Unauthorized response with the given message.
pub fn unauthorized(message: String) -> WispResponse {
  wisp.response(status_code.unauthorized)
  |> json_body(
    json.object([
      #("status", json.string("unauthorized")),
      #("reason", json.string(message)),
    ]),
  )
}

/// Return a 404 Not Found response with the given message.
pub fn not_found(message: String) -> WispResponse {
  wisp.response(status_code.not_found)
  |> json_body(
    json.object([
      #("status", json.string("not_found")),
      #("reason", json.string(message)),
    ]),
  )
}

/// Return a 409 Conflict response with the given message.
pub fn conflict(message: String) -> WispResponse {
  wisp.response(status_code.conflict)
  |> json_body(
    json.object([
      #("status", json.string("conflict")),
      #("reason", json.string(message)),
    ]),
  )
}

/// Return a 500 Internal Server Error response with the given message.
pub fn internal_server_error(message: String) -> WispResponse {
  wisp.response(status_code.internal_server_error)
  |> json_body(
    json.object([
      #("status", json.string("internal_server_error")),
      #("reason", json.string(message)),
    ]),
  )
}

/// Return a 503 Service Unavailable response with the given message.
pub fn service_unavailable(message: String) -> WispResponse {
  wisp.response(status_code.service_unavailable)
  |> json_body(
    json.object([
      #("status", json.string("service_unavailable")),
      #("reason", json.string(message)),
    ]),
  )
}

/// Return a 504 Timeout response with the given message.
pub fn timeout(message: String) -> WispResponse {
  wisp.response(status_code.timeout)
  |> json_body(
    json.object([
      #("status", json.string("timeout")),
      #("reason", json.string(message)),
    ]),
  )
}

/// Return a 200 OK response.
pub fn ok() -> WispResponse {
  wisp.response(status_code.ok)
}

/// Return a 201 Created response.
pub fn created() -> WispResponse {
  wisp.response(status_code.created)
}

//-----------------------------------------------------------------------------------------------//
//                                             Query                                             //
//-----------------------------------------------------------------------------------------------//

/// Decode the given value using the provided decoder and pass it to the next function.
/// This is useful for handling query parameters in a type-safe manner.
/// 
/// ```gleam
/// ["user", id] -> {
///   use id <- backstage.decode_param(id, identifier.decoder())
///   ...
/// }
/// ```
pub fn decode_param(
  value: String,
  decoder: decode.Decoder(a),
  next: fn(a) -> WispResponse,
) -> WispResponse {
  use value <- try(
    decode.run(dynamic.string(value), decoder)
    |> result.map_error(fn(e) {
      bad_request(
        "Failed to decode query: "
        <> string.join(list.map(e, fn(e) { "expected " <> e.expected }), ", "),
      )
    }),
  )
  next(value)
}

//-----------------------------------------------------------------------------------------------//
//                                             Body                                              //
//-----------------------------------------------------------------------------------------------//

/// Get the content type of the request
pub fn get_content_type(req: Request) -> Result(String, Nil) {
  list.key_find(req.headers, "content-type")
}

/// Check wether the content type of the request matches the expected one
pub fn is_content_type(req: Request, expected: String) -> Bool {
  case get_content_type(req) {
    Error(_) -> False
    Ok(content_type) -> {
      case string.split_once(content_type, ";") {
        Ok(#(content_type, _)) if content_type == expected -> True
        _ if content_type == expected -> True
        _ -> False
      }
    }
  }
}

fn get_raw_string_body(req: Request) -> Result(String, WispResponse) {
  let body_bits = case req.body {
    MistConnection(connection) -> {
      let req = request.map(req, fn(_) { connection })
      case mist.read_body(req, 1024 * 1024) {
        Ok(res) -> Ok(res.body)
        Error(_) -> Error(Nil)
      }
    }
    WispConnection(connection) -> {
      let req = request.map(req, fn(_) { connection })
      wisp.read_body_bits(req)
    }
  }

  use body <- result.try(
    body_bits
    |> result.map(bit_array.to_string)
    |> result.flatten()
    |> result.map_error(fn(e) {
      wisp.bad_request("Failed to read body: " <> string.inspect(e))
    }),
  )

  Ok(body)
}

pub fn get_raw_json_body(req: Request) -> Result(String, WispResponse) {
  use <- bool.guard(
    !is_content_type(req, "application/json"),
    Error(wisp.bad_request("Expected content type 'application/json'")),
  )

  get_raw_string_body(req)
}

/// Get the body of the request
pub fn get_json_body(
  req: Request,
  decoder: decode.Decoder(a),
) -> Result(a, WispResponse) {
  use body <- result.try(get_raw_json_body(req))

  json.parse(body, decoder)
  |> result.map_error(fn(e) {
    bad_request(
      "Failed to decode body: "
      <> case e {
        json.UnexpectedEndOfInput -> "Unexpected end of input"
        json.UnexpectedByte(_) -> "Unexpected byte"
        json.UnexpectedSequence(_) -> "Unexpected sequence"
        json.UnableToDecode(errors) ->
          "\n"
          <> string.join(
            list.map(errors, fn(error) {
              "- " <> decoder_error_to_string(error)
            }),
            "\n",
          )
      },
    )
  })
}

fn form_data_to_string(form: wisp.FormData) -> String {
  json.object([
    #(
      "values",
      json.object(list.map(form.values, pair.map_second(_, json.string))),
    ),
    #(
      "files",
      json.object(
        list.map(
          form.files,
          pair.map_second(_, fn(file) {
            json.object([
              #("file_name", json.string(file.file_name)),
              #("path", json.string(file.path)),
            ])
          }),
        ),
      ),
    ),
  ])
  |> json.to_string()
}

fn form_data_from_string(str: String) -> Result(wisp.FormData, Nil) {
  json.parse(str, {
    use values <- decode.field(
      "values",
      decode.dict(decode.string, decode.string),
    )
    use files <- decode.field(
      "files",
      decode.dict(decode.string, {
        use file_name <- decode.field("file_name", decode.string)
        use path <- decode.field("path", decode.string)
        decode.success(wisp.UploadedFile(file_name:, path:))
      }),
    )
    decode.success(wisp.FormData(
      values: dict.to_list(values),
      files: dict.to_list(files),
    ))
  })
  |> result.replace_error(Nil)
}

pub fn get_raw_multipart_body(
  req: Request,
) -> Result(wisp.FormData, WispResponse) {
  let assert WispConnection(connection) = req.body
  let req = request.map(req, fn(_) { connection })
  let response =
    wisp.require_form(req, fn(form) {
      wisp.ok()
      |> wisp.string_body(form_data_to_string(form))
    })
  case response.status, response.body {
    200, wisp.Text(body) -> {
      form_data_from_string(body)
      |> result.map_error(fn(_) { bad_request("Invalid form encoding") })
    }
    _, _ -> Error(response)
  }
}

fn form_data_to_dynamic(form: wisp.FormData) -> dynamic.Dynamic {
  dynamic.properties(
    list.map(form.values, fn(pair) {
      #(dynamic.string(pair.0), dynamic.string(pair.1))
    })
    |> list.append(
      list.map(form.files, fn(pair) {
        #(
          dynamic.string(pair.0),
          dynamic.properties([
            #(dynamic.string("file_name"), dynamic.string(pair.1.file_name)),
            #(dynamic.string("path"), dynamic.string(pair.1.path)),
          ]),
        )
      }),
    ),
  )
}

pub fn get_multipart_body(
  req: Request,
  decoder: decode.Decoder(a),
) -> Result(a, WispResponse) {
  use form <- result.try(get_raw_multipart_body(req))

  decode.run(form_data_to_dynamic(form), decoder)
  |> result.map_error(fn(errors) {
    bad_request(
      "Failed to decode form:\n"
      <> string.join(
        list.map(errors, fn(error) { "- " <> decoder_error_to_string(error) }),
        "\n",
      ),
    )
  })
}

fn decoder_error_to_string(error: decode.DecodeError) -> String {
  case error.expected, error.found {
    "Field", "Nothing" -> "Missing field " <> string.join(error.path, ".")
    _, _ ->
      "Expected "
      <> error.expected
      <> " at "
      <> string.join(error.path, ".")
      <> " but found "
      <> error.found
  }
}

//-----------------------------------------------------------------------------------------------//
//                                         Authorization                                         //
//-----------------------------------------------------------------------------------------------//

/// Require the given token from the request headers and execute the given function accordingly
pub fn get_authorization(req: Request) -> Result(String, Nil) {
  list.find(req.headers, fn(entry) { entry.0 == "authorization" })
  |> result.map(fn(res) {
    let token = res.1
    case string.starts_with(token, "Bearer ") {
      True -> string.slice(token, 7, string.length(token))
      False -> token
    }
  })
}

/// Require the given token from the request headers and execute the given function accordingly
pub fn require_authorization(req: Request) -> Result(String, WispResponse) {
  get_authorization(req)
  |> result.map_error(fn(_) { unauthorized("Missing authorization header") })
}

//-----------------------------------------------------------------------------------------------//
//                                            Utility                                            //
//-----------------------------------------------------------------------------------------------//

/// Attempt to execute the given function with the value inside the `Result`. This function is 
/// similar to the result.try function, returning the
pub fn try(in: Result(a, b), fun: fn(a) -> b) -> b {
  case in {
    Ok(value) -> fun(value)
    Error(value) -> value
  }
}
