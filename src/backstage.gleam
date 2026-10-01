import backstage/backstage_core
import dynamic/decode
import dynamic/encode
import gleam/function
import gleam/http
import gleam/result
import openapi/openapi
import openapi/openapi_type

/// The common request type that supports both Wisp and Mist.
pub type Request =
  backstage_core.Request

/// The response type for Mist.
pub type MistResponse =
  backstage_core.MistResponse

/// The response type for Wisp.
pub type WispResponse =
  backstage_core.WispResponse

/// Attempt to execute the given function with the value inside the `Result`. This function is 
/// similar to the result.try function, returning the
pub const try = backstage_core.try

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                             Scope                                             //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

pub type OpenAPIScope =
  backstage_core.OpenAPIScope

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                          Route Base                                           //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

pub fn get(route: String) -> Next(EndOfSequence, EndOfSequence) {
  let single = fn(_) { Ok(EndOfSequence) }
  backstage_core.Next(
    doc: fn(doc) {
      backstage_core.create_scope(
        doc: doc
          |> openapi.on_path(route, fn(path) {
            openapi.path.get(path, function.identity)
          }),
        method: http.Get,
        route: route,
      )
    },
    single: single,
    fun: fn(request, callback) {
      use value <- try(single(request))
      callback(value)
    },
  )
}

pub fn post(route: String) -> Next(EndOfSequence, EndOfSequence) {
  let single = fn(_) { Ok(EndOfSequence) }
  backstage_core.Next(
    doc: fn(doc) {
      backstage_core.create_scope(
        doc: doc
          |> openapi.on_path(route, fn(path) {
            openapi.path.post(path, function.identity)
          }),
        method: http.Post,
        route: route,
      )
    },
    single: single,
    fun: fn(request, callback) {
      use value <- try(single(request))
      callback(value)
    },
  )
}

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                        Route Callback                                         //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

pub type Next(data, next) =
  backstage_core.Next(data, next)

pub type SequentialNext(data, next) =
  backstage_core.SequentialNext(data, next)

/// Get the OpenAPI document from the given route definition
pub fn doc(
  next: Next(data, next),
  openapi: openapi.OpenAPI,
) -> openapi.OpenAPI {
  next.doc(openapi)
  |> backstage_core.openapi_scope_doc()
}

/// The end of a sequence in the routing system
pub opaque type EndOfSequence {
  EndOfSequence
}

/// A sequential element in the routing system
pub type Sequential(data, next) =
  backstage_core.Sequential(data, next)

/// Extract the data and next element from a sequential element
/// 
/// Usage:
/// ```gleam
/// use data, next <- backstage.extract(seq)
/// ```
pub fn extract(seq: Sequential(data, next), fun: fn(data, next) -> a) -> a {
  fun(seq.data, seq.next)
}

/// Extract the first element of a sequence
pub fn extract1(seq: Sequential(data, _)) -> data {
  seq.data
}

/// Extract the second element of a sequence
pub fn extract2(seq: Sequential(_, Sequential(data, _))) -> data {
  seq.next.data
}

/// Extract the third element of a sequence
pub fn extract3(
  seq: Sequential(_, Sequential(_, Sequential(data, _))),
) -> data {
  seq.next.next.data
}

/// Extract the fourth element of a sequence
pub fn extract4(
  seq: Sequential(_, Sequential(_, Sequential(_, Sequential(data, _)))),
) -> data {
  seq.next.next.next.data
}

/// Extract the fifth element of a sequence
pub fn extract5(
  seq: Sequential(
    _,
    Sequential(_, Sequential(_, Sequential(_, Sequential(data, _)))),
  ),
) -> data {
  seq.next.next.next.next.data
}

/// Extract the sixth element of a sequence
pub fn extract6(
  seq: Sequential(
    _,
    Sequential(
      _,
      Sequential(_, Sequential(_, Sequential(_, Sequential(data, _)))),
    ),
  ),
) -> data {
  seq.next.next.next.next.next.data
}

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                        Authentication                                         //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

/// The type representing Bearer authentication in the system
pub type BearerAuth {
  BearerAuth(token: String)
}

/// Require the given token from the request headers and execute the given function accordingly
pub fn require_authorization(
  req: Request,
  unauthorized: UnauthorizedResponse,
) -> Result(String, WispResponse) {
  backstage_core.get_authorization(req)
  |> result.map_error(fn(_) {
    unauthorized.apply("Missing authorization header")
  })
}

/// Add bearer authentication to the route.
pub fn bearer_auth(
  next: Next(_, next),
  name: String,
) -> SequentialNext(BearerAuth, next) {
  let unauthorized = unauthorized(next)
  backstage_core.sequential(
    next: next,
    doc: fn(doc) {
      doc
      |> unauthorized.doc()
      |> backstage_core.modify_operation(fn(operation) {
        operation
        |> openapi.operation.security(name)
      })
      |> backstage_core.modify_doc(fn(doc) {
        openapi.components.security_scheme(doc, name, "http", fn(security) {
          security
          |> openapi.security_scheme.scheme("bearer")
          |> openapi.security_scheme.bearer_format("JWT")
        })
      })
    },
    single: fn(request) {
      use unauthorized <- result.try(unauthorized.single(request))
      use token <- result.try(require_authorization(request, unauthorized))

      Ok(BearerAuth(token: token))
    },
  )
}

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                             Body                                              //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

/// The type representing the body of a request
pub type Body(body) {
  Body(value: body)
}

/// Add a json body with the given decoder to the route
pub fn json_body(
  next: Next(_, next),
  decoder: decode.Decoder(body),
) -> SequentialNext(Body(body), next) {
  backstage_core.sequential(
    next: next,
    doc: fn(doc) {
      doc
      |> next.doc()
      |> backstage_core.modify_operation(fn(operation) {
        operation
        |> openapi.operation.request_body(fn(request_body) {
          request_body
          |> openapi.request_body.content("application/json", fn(media) {
            media
            |> openapi.media_type.schema("", fn(_) {
              decoder.doc() |> openapi_type.to_schema()
            })
          })
        })
      })
    },
    single: fn(request) {
      use body <- result.try(backstage_core.get_json_body(
        request,
        decoder.decoder,
      ))

      Ok(Body(value: body))
    },
  )
}

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                           Response                                            //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

/// The type representing a JSON response from the server
pub type JsonResponse(response) {
  JsonResponse(apply: fn(response) -> WispResponse)
}

pub fn json_response(
  next: Next(_, next),
  code: Int,
  summary: String,
  encoder: encode.Encoder(response),
) -> SequentialNext(JsonResponse(response), next) {
  backstage_core.json_response_internal(
    next,
    code,
    encoder,
    summary,
    JsonResponse,
  )
}

pub type BadRequestResponse {
  BadRequestResponse(apply: fn(String) -> WispResponse)
}

pub fn bad_request(
  next: Next(_, next),
) -> SequentialNext(BadRequestResponse, next) {
  backstage_core.json_response_internal(
    next,
    backstage_core.status_code.bad_request,
    backstage_core.error_response_encoder("bad_request"),
    "Bad request",
    BadRequestResponse,
  )
}

pub type UnauthorizedResponse {
  UnauthorizedResponse(apply: fn(String) -> WispResponse)
}

pub fn unauthorized(
  next: Next(_, next),
) -> SequentialNext(UnauthorizedResponse, next) {
  backstage_core.json_response_internal(
    next,
    backstage_core.status_code.unauthorized,
    backstage_core.error_response_encoder("unauthorized"),
    "Unauthorized",
    UnauthorizedResponse,
  )
}

pub type NotFoundResponse {
  NotFoundResponse(apply: fn(String) -> WispResponse)
}

pub fn not_found(
  next: Next(_, next),
) -> SequentialNext(NotFoundResponse, next) {
  backstage_core.json_response_internal(
    next,
    backstage_core.status_code.not_found,
    backstage_core.error_response_encoder("not_found"),
    "Not found",
    NotFoundResponse,
  )
}

pub type ConflictResponse {
  ConflictResponse(apply: fn(String) -> WispResponse)
}

pub fn conflict(next: Next(_, next)) -> SequentialNext(ConflictResponse, next) {
  backstage_core.json_response_internal(
    next,
    backstage_core.status_code.conflict,
    backstage_core.error_response_encoder("conflict"),
    "Conflict",
    ConflictResponse,
  )
}

pub type InternalServerErrorResponse {
  InternalServerErrorResponse(apply: fn(String) -> WispResponse)
}

pub fn internal_server_error(
  next: Next(_, next),
) -> SequentialNext(InternalServerErrorResponse, next) {
  backstage_core.json_response_internal(
    next,
    backstage_core.status_code.internal_server_error,
    backstage_core.error_response_encoder("internal_server_error"),
    "Internal server error",
    InternalServerErrorResponse,
  )
}

pub type ServiceUnavailableResponse {
  ServiceUnavailableResponse(apply: fn(String) -> WispResponse)
}

pub fn service_unavailable(
  next: Next(_, next),
) -> SequentialNext(ServiceUnavailableResponse, next) {
  backstage_core.json_response_internal(
    next,
    backstage_core.status_code.service_unavailable,
    backstage_core.error_response_encoder("service_unavailable"),
    "Service unavailable",
    ServiceUnavailableResponse,
  )
}

pub type TimeoutResponse {
  TimeoutResponse(apply: fn(String) -> WispResponse)
}

pub fn timeout(next: Next(_, next)) -> SequentialNext(TimeoutResponse, next) {
  backstage_core.json_response_internal(
    next,
    backstage_core.status_code.timeout,
    backstage_core.error_response_encoder("timeout"),
    "Timeout",
    TimeoutResponse,
  )
}

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                            Runtime                                            //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

/// Run the route definition with the given body and for the given request.
pub fn run(
  def: Next(data, next),
  request: Request,
  next: fn(next) -> WispResponse,
) {
  def.fun(request, next)
}
