import backstage/backstage_core
import backstage/pagination
import dynamic/decode
import dynamic/encode
import dynamic/serialize
import dynamic/spec
import gleam/function
import gleam/http
import gleam/option
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

/// Create a GET route with the given [route] path.
pub fn get(route: String) -> RouteSpecBuilder {
  backstage_core.RouteSpecBuilder(doc: fn(doc) {
    backstage_core.create_scope(
      doc: doc
        |> openapi.on_path(route, fn(path) {
          openapi.path.get(path, function.identity)
        }),
      method: http.Get,
      route: route,
    )
  })
}

/// Create a POST route with the given [route] path.
pub fn post(route: String) -> RouteSpecBuilder {
  backstage_core.RouteSpecBuilder(doc: fn(doc) {
    backstage_core.create_scope(
      doc: doc
        |> openapi.on_path(route, fn(path) {
          openapi.path.post(path, function.identity)
        }),
      method: http.Post,
      route: route,
    )
  })
}

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                        Route Modifier                                         //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

/// Set the [summary] of the route.
pub fn summary(spec: RouteSpecBuilder, summary: String) -> RouteSpecBuilder {
  backstage_core.RouteSpecBuilder(doc: fn(doc) {
    doc
    |> spec.doc()
    |> backstage_core.modify_operation(fn(operation) {
      operation |> openapi.operation.summary(summary)
    })
  })
}

/// Set the [tag] of the route.
pub fn tag(spec: RouteSpecBuilder, tag: String) -> RouteSpecBuilder {
  backstage_core.RouteSpecBuilder(doc: fn(doc) {
    doc
    |> spec.doc()
    |> backstage_core.modify_operation(fn(operation) {
      operation |> openapi.operation.tag(tag)
    })
  })
}

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                        Route Callback                                         //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

pub type RouteSpecBuilder =
  backstage_core.RouteSpecBuilder

pub type RouteSpec(data) =
  backstage_core.RouteSpec(data)

pub type RouteCapability(data, object) =
  backstage_core.RouteCapability(data, object)

/// Get the OpenAPI document from the given route definition
pub fn doc(spec: RouteSpec(_), openapi: openapi.OpenAPI) -> openapi.OpenAPI {
  openapi
  |> spec.doc()
  |> backstage_core.openapi_scope_doc()
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
  spec: RouteSpecBuilder,
  name: String,
  next: fn(RouteSpecBuilder, RouteCapability(BearerAuth, object)) ->
    RouteSpec(object),
) -> RouteSpec(object) {
  use spec, unauthorized <- unauthorized(spec)

  spec
  |> backstage_core.modify_spec(fn(scope) {
    scope
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
  })
  |> next(
    backstage_core.RouteCapability(get: fn(request, next) {
      use unauthorized <- unauthorized.get(request)
      use token <- result.try(require_authorization(request, unauthorized))
      next(BearerAuth(token: token))
    }),
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
  spec: RouteSpecBuilder,
  decoder: decode.Decoder(body),
  next: fn(RouteSpecBuilder, RouteCapability(Body(body), object)) ->
    RouteSpec(object),
) -> RouteSpec(object) {
  spec
  |> backstage_core.modify_spec(fn(scope) {
    scope
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
  })
  |> next(
    backstage_core.capability(fn(request) {
      backstage_core.get_json_body(request, decoder.decoder)
      |> result.map(Body)
    }),
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
  spec: RouteSpecBuilder,
  code: Int,
  summary: String,
  encoder: encode.Encoder(response),
  next: fn(RouteSpecBuilder, RouteCapability(JsonResponse(response), object)) ->
    RouteSpec(object),
) -> RouteSpec(object) {
  backstage_core.json_response_internal(
    spec,
    code,
    encoder,
    summary,
    JsonResponse,
    next,
  )
}

pub type BadRequestResponse {
  BadRequestResponse(apply: fn(String) -> WispResponse)
}

pub fn bad_request(
  spec: RouteSpecBuilder,
  next: fn(RouteSpecBuilder, RouteCapability(BadRequestResponse, object)) ->
    RouteSpec(object),
) -> RouteSpec(object) {
  backstage_core.json_response_internal(
    spec,
    backstage_core.status_code.bad_request,
    backstage_core.error_response_serializer(option.Some("bad_request"))
      |> serialize.encoder()
      |> encode.map(backstage_core.ErrorResponse(
        status: "bad_request",
        reason: _,
      )),
    "Bad request",
    BadRequestResponse,
    next,
  )
}

pub type UnauthorizedResponse {
  UnauthorizedResponse(apply: fn(String) -> WispResponse)
}

pub fn unauthorized(
  spec: RouteSpecBuilder,
  next: fn(RouteSpecBuilder, RouteCapability(UnauthorizedResponse, object)) ->
    RouteSpec(object),
) -> RouteSpec(object) {
  backstage_core.json_response_internal(
    spec,
    backstage_core.status_code.unauthorized,
    backstage_core.error_response_serializer(option.Some("unauthorized"))
      |> serialize.encoder()
      |> encode.map(backstage_core.ErrorResponse(
        status: "unauthorized",
        reason: _,
      )),
    "Unauthorized",
    UnauthorizedResponse,
    next,
  )
}

pub type NotFoundResponse {
  NotFoundResponse(apply: fn(String) -> WispResponse)
}

pub fn not_found(
  spec: RouteSpecBuilder,
  next: fn(RouteSpecBuilder, RouteCapability(NotFoundResponse, object)) ->
    RouteSpec(object),
) -> RouteSpec(object) {
  backstage_core.json_response_internal(
    spec,
    backstage_core.status_code.not_found,
    backstage_core.error_response_serializer(option.Some("not_found"))
      |> serialize.encoder()
      |> encode.map(backstage_core.ErrorResponse(status: "not_found", reason: _)),
    "Not found",
    NotFoundResponse,
    next,
  )
}

pub type ConflictResponse {
  ConflictResponse(apply: fn(String) -> WispResponse)
}

pub fn conflict(
  spec: RouteSpecBuilder,
  next: fn(RouteSpecBuilder, RouteCapability(ConflictResponse, object)) ->
    RouteSpec(object),
) -> RouteSpec(object) {
  backstage_core.json_response_internal(
    spec,
    backstage_core.status_code.conflict,
    backstage_core.error_response_serializer(option.Some("conflict"))
      |> serialize.encoder()
      |> encode.map(backstage_core.ErrorResponse(status: "conflict", reason: _)),
    "Conflict",
    ConflictResponse,
    next,
  )
}

pub type InternalServerErrorResponse {
  InternalServerErrorResponse(apply: fn(String) -> WispResponse)
}

pub fn internal_server_error(
  spec: RouteSpecBuilder,
  next: fn(
    RouteSpecBuilder,
    RouteCapability(InternalServerErrorResponse, object),
  ) -> RouteSpec(object),
) -> RouteSpec(object) {
  backstage_core.json_response_internal(
    spec,
    backstage_core.status_code.internal_server_error,
    backstage_core.error_response_serializer(option.Some(
      "internal_server_error",
    ))
      |> serialize.encoder()
      |> encode.map(backstage_core.ErrorResponse(
        status: "internal_server_error",
        reason: _,
      )),
    "Internal server error",
    InternalServerErrorResponse,
    next,
  )
}

pub type ServiceUnavailableResponse {
  ServiceUnavailableResponse(apply: fn(String) -> WispResponse)
}

pub fn service_unavailable(
  spec: RouteSpecBuilder,
  next: fn(
    RouteSpecBuilder,
    RouteCapability(ServiceUnavailableResponse, object),
  ) -> RouteSpec(object),
) -> RouteSpec(object) {
  backstage_core.json_response_internal(
    spec,
    backstage_core.status_code.service_unavailable,
    backstage_core.error_response_serializer(option.Some("service_unavailable"))
      |> serialize.encoder()
      |> encode.map(backstage_core.ErrorResponse(
        status: "service_unavailable",
        reason: _,
      )),
    "Service unavailable",
    ServiceUnavailableResponse,
    next,
  )
}

pub type TimeoutResponse {
  TimeoutResponse(apply: fn(String) -> WispResponse)
}

pub fn timeout(
  spec: RouteSpecBuilder,
  next: fn(RouteSpecBuilder, RouteCapability(TimeoutResponse, object)) ->
    RouteSpec(object),
) -> RouteSpec(object) {
  backstage_core.json_response_internal(
    spec,
    backstage_core.status_code.timeout,
    backstage_core.error_response_serializer(option.Some("timeout"))
      |> serialize.encoder()
      |> encode.map(backstage_core.ErrorResponse(status: "timeout", reason: _)),
    "Timeout",
    TimeoutResponse,
    next,
  )
}

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                        Query Parameter                                        //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

pub fn pagination(
  spec: RouteSpecBuilder,
  config: pagination.PaginationConfig(a, b, backstage_core.Connection),
  next: fn(RouteSpecBuilder, RouteCapability(a, object)) -> RouteSpec(object),
) -> RouteSpec(object) {
  spec
  |> backstage_core.modify_spec(fn(scope) {
    scope
    |> backstage_core.modify_operation(fn(operation) {
      case config {
        pagination.SimplePaginationConfig(default_page:, default_per_page:, ..) -> {
          operation
          |> openapi.operation.parameter(
            "page",
            openapi.ParameterInQuery,
            fn(parameter) {
              parameter
              |> openapi.parameter.schema("", fn(_) {
                openapi_type.integer()
                |> openapi_type.default(spec.integer(default_page))
                |> openapi_type.to_schema()
              })
            },
          )
          |> openapi.operation.parameter(
            "per_page",
            openapi.ParameterInQuery,
            fn(parameter) {
              parameter
              |> openapi.parameter.schema("", fn(_) {
                openapi_type.integer()
                |> openapi_type.default(spec.integer(default_per_page))
                |> openapi_type.to_schema()
              })
            },
          )
        }
        pagination.AfterPaginationConfig(
          default_after:,
          after_serializer:,
          default_per_page:,
          ..,
        ) -> {
          operation
          |> openapi.operation.parameter(
            "after",
            openapi.ParameterInQuery,
            fn(parameter) {
              parameter
              |> openapi.parameter.schema("", fn(_) {
                after_serializer.doc()
                |> openapi_type.default(serialize.encode(
                  default_after,
                  after_serializer,
                ))
                |> openapi_type.to_schema()
              })
            },
          )
          |> openapi.operation.parameter(
            "per_page",
            openapi.ParameterInQuery,
            fn(parameter) {
              parameter
              |> openapi.parameter.schema("", fn(_) {
                openapi_type.integer()
                |> openapi_type.default(spec.integer(default_per_page))
                |> openapi_type.to_schema()
              })
            },
          )
        }
        pagination.BeforePaginationConfig(
          default_before:,
          before_serializer:,
          default_per_page:,
          ..,
        ) -> {
          operation
          |> openapi.operation.parameter(
            "before",
            openapi.ParameterInQuery,
            fn(parameter) {
              parameter
              |> openapi.parameter.schema("", fn(_) {
                before_serializer.doc()
                |> openapi_type.default(serialize.encode(
                  default_before,
                  before_serializer,
                ))
                |> openapi_type.to_schema()
              })
            },
          )
          |> openapi.operation.parameter(
            "per_page",
            openapi.ParameterInQuery,
            fn(parameter) {
              parameter
              |> openapi.parameter.schema("", fn(_) {
                openapi_type.integer()
                |> openapi_type.default(spec.integer(default_per_page))
                |> openapi_type.to_schema()
              })
            },
          )
        }
      }
    })
  })
  |> next(
    backstage_core.capability(fn(request) {
      Ok(pagination.parse(config, request))
    }),
  )
}

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                            Runtime                                            //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

pub fn build(
  spec: RouteSpecBuilder,
  next: fn(Request) -> Result(object, WispResponse),
) -> RouteSpec(object) {
  backstage_core.RouteSpec(doc: spec.doc, build: next)
}

/// Run the route definition with the given body and for the given request.
pub fn run(
  spec: RouteSpec(object),
  request: Request,
  next: fn(object) -> WispResponse,
) {
  use object <- try(spec.build(request))

  next(object)
}
