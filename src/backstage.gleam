import backstage/backstage_core
import backstage/pagination
import dynamic/decode
import dynamic/encode
import dynamic/serialize
import dynamic/spec
import gleam/dynamic
import gleam/function
import gleam/http
import gleam/http/request
import gleam/json
import gleam/list
import gleam/option
import gleam/pair
import gleam/result
import gleam/uri
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

/// Create a DELETE route with the given [route] path.
pub fn delete(route: String) -> RouteSpecBuilder {
  backstage_core.RouteSpecBuilder(doc: fn(doc) {
    backstage_core.create_scope(
      doc: doc
        |> openapi.on_path(route, fn(path) {
          openapi.path.delete(path, function.identity)
        }),
      method: http.Delete,
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

/// Set the [summary] of the route.
pub fn description(
  spec: RouteSpecBuilder,
  description: String,
) -> RouteSpecBuilder {
  backstage_core.RouteSpecBuilder(doc: fn(doc) {
    doc
    |> spec.doc()
    |> backstage_core.modify_operation(fn(operation) {
      operation |> openapi.operation.description(description)
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
          |> openapi.media_type.set_schema(
            decoder.doc() |> openapi_type.to_schema(),
          )
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

/// Add a multipart body with the given decoder to the route
pub fn multipart_body(
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
        |> openapi.request_body.content("multipart/form-data", fn(media) {
          media
          |> openapi.media_type.set_schema(
            decoder.doc() |> openapi_type.to_schema(),
          )
        })
      })
    })
  })
  |> next(
    backstage_core.capability(fn(request) {
      backstage_core.get_multipart_body(request, decoder.decoder)
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
//                                          Parameters                                           //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

pub type PathParameter(a) {
  PathParameter(value: a)
}

fn path_parameter_internal(
  spec: RouteSpecBuilder,
  name: String,
  decoder: decode.Decoder(a),
  is_json: Bool,
  next: fn(RouteSpecBuilder, RouteCapability(PathParameter(a), object)) ->
    RouteSpec(object),
) -> RouteSpec(object) {
  use spec, bad_request <- bad_request(spec)

  spec
  |> backstage_core.modify_spec(fn(scope) {
    scope
    |> backstage_core.modify_operation(fn(operation) {
      operation
      |> openapi.operation.parameter(
        name,
        openapi.ParameterInPath,
        fn(parameter) {
          parameter
          |> openapi.parameter.required(True)
          |> openapi.parameter.set_schema(
            decoder.doc() |> openapi_type.to_schema(),
          )
        },
      )
    })
  })
  |> next(
    backstage_core.RouteCapability(fn(request, next) {
      use bad_request <- bad_request.get(request)

      let path_segments =
        openapi.openapi()
        |> spec.doc()
        |> backstage_core.openapi_scope_path()
        |> uri.path_segments()
        |> list.index_map(pair.new)

      use segment_index <- result.try(
        list.key_find(path_segments, "{" <> name <> "}")
        |> result.map_error(fn(_) {
          bad_request.apply("Failed to find path segment for '" <> name <> "'")
        }),
      )

      use raw_value <- result.try(
        request.path_segments(request)
        |> list.index_map(fn(segment, index) { pair.new(index, segment) })
        |> list.key_find(segment_index)
        |> result.map_error(fn(_) {
          bad_request.apply("Failed to find path segment for '" <> name <> "'")
        }),
      )

      use value <- result.try(case is_json {
        True ->
          json.parse(raw_value, decoder.decoder)
          |> result.map_error(fn(_) {
            bad_request.apply("Failed to decode '" <> name <> "'")
          })
        False ->
          decode.run(dynamic.string(raw_value), decoder)
          |> result.map_error(fn(_) {
            bad_request.apply("Failed to decode '" <> name <> "'")
          })
      })

      next(PathParameter(value))
    }),
  )
}

pub fn path_parameter(
  spec: RouteSpecBuilder,
  name: String,
  decoder: decode.Decoder(a),
  next: fn(RouteSpecBuilder, RouteCapability(PathParameter(a), object)) ->
    RouteSpec(object),
) -> RouteSpec(object) {
  path_parameter_internal(spec, name, decoder, False, next)
}

pub fn json_path_parameter(
  spec: RouteSpecBuilder,
  name: String,
  decoder: decode.Decoder(a),
  next: fn(RouteSpecBuilder, RouteCapability(PathParameter(a), object)) ->
    RouteSpec(object),
) -> RouteSpec(object) {
  path_parameter_internal(spec, name, decoder, True, next)
}

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                        Query Parameter                                        //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

pub type QueryParameter(a) {
  QueryParameter(value: a)
}

fn query_parameter_internal(
  spec: RouteSpecBuilder,
  name: String,
  serializer: serialize.Serializer(a),
  default: option.Option(a),
  is_json: Bool,
  next: fn(RouteSpecBuilder, RouteCapability(QueryParameter(a), object)) ->
    RouteSpec(object),
) -> RouteSpec(object) {
  use spec, bad_request <- bad_request(spec)

  spec
  |> backstage_core.modify_spec(fn(scope) {
    scope
    |> backstage_core.modify_operation(fn(operation) {
      operation
      |> openapi.operation.parameter(
        name,
        openapi.ParameterInQuery,
        fn(parameter) {
          parameter
          |> openapi.parameter.required(option.is_none(default))
          |> openapi.parameter.set_schema(
            serializer.doc() |> openapi_type.to_schema(),
          )
        },
      )
    })
  })
  |> next(
    backstage_core.RouteCapability(fn(request, next) {
      use bad_request <- bad_request.get(request)

      use data <- result.try(
        request.get_query(request)
        |> result.unwrap([])
        |> list.key_find(name)
        |> result.map(fn(value) {
          case is_json {
            True ->
              json.parse(value, serializer.decoder)
              |> result.map_error(fn(_) {
                bad_request.apply("Failed to decode '" <> name <> "'")
              })
            False ->
              serialize.decode(dynamic.string(value), serializer)
              |> result.map_error(fn(_) {
                bad_request.apply("Failed to decode '" <> name <> "'")
              })
          }
        })
        |> result.unwrap(case default {
          option.Some(default) -> Ok(default)
          option.None ->
            Error(bad_request.apply("Missing query parameter '" <> name <> "'"))
        }),
      )

      next(QueryParameter(data))
    }),
  )
}

pub fn query_parameter(
  spec: RouteSpecBuilder,
  name: String,
  serializer: serialize.Serializer(a),
  default: option.Option(a),
  next: fn(RouteSpecBuilder, RouteCapability(QueryParameter(a), object)) ->
    RouteSpec(object),
) -> RouteSpec(object) {
  query_parameter_internal(spec, name, serializer, default, False, next)
}

pub fn json_query_parameter(
  spec: RouteSpecBuilder,
  name: String,
  serializer: serialize.Serializer(a),
  default: option.Option(a),
  next: fn(RouteSpecBuilder, RouteCapability(QueryParameter(a), object)) ->
    RouteSpec(object),
) -> RouteSpec(object) {
  query_parameter_internal(spec, name, serializer, default, True, next)
}

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
        pagination.SimplePaginationConfig(
          default_page:,
          default_per_page:,
          max_per_page:,
          ..,
        ) -> {
          operation
          |> openapi.operation.parameter(
            "page",
            openapi.ParameterInQuery,
            fn(parameter) {
              parameter
              |> openapi.parameter.set_schema(
                openapi_type.integer()
                |> openapi_type.default(spec.integer(default_page))
                |> openapi_type.to_schema(),
              )
            },
          )
          |> openapi.operation.parameter(
            "per_page",
            openapi.ParameterInQuery,
            fn(parameter) {
              parameter
              |> openapi.parameter.set_schema(
                openapi_type.integer()
                |> openapi_type.default(spec.integer(default_per_page))
                |> openapi_type.min(spec.integer(0))
                |> openapi_type.max(spec.integer(max_per_page))
                |> openapi_type.to_schema(),
              )
            },
          )
        }
        pagination.AfterPaginationConfig(
          default_after:,
          after_serializer:,
          default_per_page:,
          max_per_page:,
          ..,
        ) -> {
          operation
          |> openapi.operation.parameter(
            "after",
            openapi.ParameterInQuery,
            fn(parameter) {
              parameter
              |> openapi.parameter.set_schema(
                after_serializer.doc()
                |> openapi_type.default(serialize.encode(
                  default_after,
                  after_serializer,
                ))
                |> openapi_type.to_schema(),
              )
            },
          )
          |> openapi.operation.parameter(
            "per_page",
            openapi.ParameterInQuery,
            fn(parameter) {
              parameter
              |> openapi.parameter.set_schema(
                openapi_type.integer()
                |> openapi_type.default(spec.integer(default_per_page))
                |> openapi_type.min(spec.integer(0))
                |> openapi_type.max(spec.integer(max_per_page))
                |> openapi_type.to_schema(),
              )
            },
          )
        }
        pagination.BeforePaginationConfig(
          default_before:,
          before_serializer:,
          default_per_page:,
          max_per_page:,
          ..,
        ) -> {
          operation
          |> openapi.operation.parameter(
            "before",
            openapi.ParameterInQuery,
            fn(parameter) {
              parameter
              |> openapi.parameter.set_schema(
                before_serializer.doc()
                |> openapi_type.default(serialize.encode(
                  default_before,
                  before_serializer,
                ))
                |> openapi_type.to_schema(),
              )
            },
          )
          |> openapi.operation.parameter(
            "per_page",
            openapi.ParameterInQuery,
            fn(parameter) {
              parameter
              |> openapi.parameter.set_schema(
                openapi_type.integer()
                |> openapi_type.default(spec.integer(default_per_page))
                |> openapi_type.min(spec.integer(0))
                |> openapi_type.max(spec.integer(max_per_page))
                |> openapi_type.to_schema(),
              )
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
