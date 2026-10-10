import dynamic/decode
import dynamic/encode
import dynamic/serialize
import dynamic/spec
import gleam/bool
import gleam/dynamic
import gleam/function
import gleam/http
import gleam/http/request
import gleam/json
import gleam/list
import gleam/option
import gleam/pair
import gleam/result
import gleam/string
import gleam/uri
import offstage/offstage_core
import offstage/pagination
import openapi/openapi
import openapi/openapi_type
import wisp

/// The common request type that supports both Wisp and Mist.
pub type Request =
  offstage_core.Request

/// The response type for Mist.
pub type MistResponse =
  offstage_core.MistResponse

/// The response type for Wisp.
pub type WispResponse =
  offstage_core.WispResponse

/// Attempt to execute the given function with the value inside the `Result`. This function is 
/// similar to the result.try function, returning the
pub const try = offstage_core.try

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                             Scope                                             //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

pub type OpenAPIScope =
  offstage_core.OpenAPIScope

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                          Route Base                                           //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

/// Create a GET route with the given [route] path.
pub fn get(route: String) -> RouteSpecBuilder {
  offstage_core.create_spec_builder(
    route: route,
    method: http.Get,
    doc: fn(doc) {
      openapi.on_path(doc, route, fn(path) {
        openapi.path.get(path, function.identity)
      })
    },
  )
}

/// Create a POST route with the given [route] path.
pub fn post(route: String) -> RouteSpecBuilder {
  offstage_core.create_spec_builder(
    route: route,
    method: http.Post,
    doc: fn(doc) {
      openapi.on_path(doc, route, fn(path) {
        openapi.path.post(path, function.identity)
      })
    },
  )
}

/// Create a DELETE route with the given [route] path.
pub fn delete(route: String) -> RouteSpecBuilder {
  offstage_core.create_spec_builder(
    route: route,
    method: http.Delete,
    doc: fn(doc) {
      openapi.on_path(doc, route, fn(path) {
        openapi.path.delete(path, function.identity)
      })
    },
  )
}

/// Create a PUT route with the given [route] path.
pub fn put(route: String) -> RouteSpecBuilder {
  offstage_core.create_spec_builder(
    route: route,
    method: http.Put,
    doc: fn(doc) {
      openapi.on_path(doc, route, fn(path) {
        openapi.path.put(path, function.identity)
      })
    },
  )
}

/// Create a PATCH route with the given [route] path.
pub fn patch(route: String) -> RouteSpecBuilder {
  offstage_core.create_spec_builder(
    route: route,
    method: http.Patch,
    doc: fn(doc) {
      openapi.on_path(doc, route, fn(path) {
        openapi.path.patch(path, function.identity)
      })
    },
  )
}

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                        Route Modifier                                         //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

/// Set the [summary] of the route.
pub fn summary(spec: RouteSpecBuilder, summary: String) -> RouteSpecBuilder {
  use doc <- offstage_core.modify_spec(spec)
  use operation <- offstage_core.modify_operation(doc)

  openapi.operation.summary(operation, summary)
}

/// Set the [summary] of the route.
pub fn description(
  spec: RouteSpecBuilder,
  description: String,
) -> RouteSpecBuilder {
  use doc <- offstage_core.modify_spec(spec)
  use operation <- offstage_core.modify_operation(doc)

  openapi.operation.description(operation, description)
}

/// Set the [tag] of the route.
pub fn tag(spec: RouteSpecBuilder, tag: String) -> RouteSpecBuilder {
  use doc <- offstage_core.modify_spec(spec)
  use operation <- offstage_core.modify_operation(doc)

  openapi.operation.tag(operation, tag)
}

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                        Route Callback                                         //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

pub type RouteSpecBuilder =
  offstage_core.RouteSpecBuilder

pub type RouteSpec =
  offstage_core.RouteSpec

pub type RouteCapability(data, object) =
  offstage_core.RouteCapability(data, object)

/// Get the OpenAPI document from the given route definition
pub fn doc(spec: RouteSpec, openapi: openapi.OpenAPI) -> openapi.OpenAPI {
  openapi
  |> spec.doc()
  |> offstage_core.openapi_scope_doc()
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
  offstage_core.get_authorization(req)
  |> result.map_error(fn(_) {
    unauthorized.apply("Missing authorization header")
  })
}

/// Add bearer authentication to the route.
pub fn bearer_auth(
  spec: RouteSpecBuilder,
  name: String,
  next: fn(RouteSpecBuilder, RouteCapability(BearerAuth, object)) -> RouteSpec,
) -> RouteSpec {
  use spec, unauthorized <- unauthorized(spec)

  offstage_core.modify_spec(spec, fn(scope) {
    scope
    |> offstage_core.modify_operation(openapi.operation.security(_, name))
    |> offstage_core.modify_doc(fn(doc) {
      use security <- openapi.components.security_scheme(doc, name, "http")

      security
      |> openapi.security_scheme.scheme("bearer")
      |> openapi.security_scheme.bearer_format("JWT")
    })
  })
  |> next(
    offstage_core.capability(fn(request) {
      use unauthorized <- unauthorized.get(request)
      use token <- result.try(require_authorization(request, unauthorized))
      Ok(BearerAuth(token: token))
    }),
  )
}

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                             Body                                              //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

/// Add a json body with the given decoder to the route
pub fn json_body(
  spec: RouteSpecBuilder,
  decoder: decode.Decoder(body),
  next: fn(RouteSpecBuilder, RouteCapability(body, object)) -> RouteSpec,
) -> RouteSpec {
  spec
  |> offstage_core.modify_spec(fn(scope) {
    use operation <- offstage_core.modify_operation(scope)
    use request_body <- openapi.operation.request_body(operation)
    use media <- openapi.request_body.content(request_body, "application/json")

    openapi.media_type.set_schema(media, openapi_type.to_schema(decoder.doc()))
  })
  |> next(
    offstage_core.capability(fn(request) {
      offstage_core.get_json_body(request, decoder.decoder)
    }),
  )
}

/// Add a multipart body with the given decoder to the route
pub fn multipart_body(
  spec: RouteSpecBuilder,
  decoder: decode.Decoder(body),
  next: fn(RouteSpecBuilder, RouteCapability(body, object)) -> RouteSpec,
) -> RouteSpec {
  spec
  |> offstage_core.modify_spec(fn(scope) {
    use operation <- offstage_core.modify_operation(scope)
    use request_body <- openapi.operation.request_body(operation)
    use media <- openapi.request_body.content(
      request_body,
      "multipart/form-data",
    )

    openapi.media_type.set_schema(media, openapi_type.to_schema(decoder.doc()))
  })
  |> next(
    offstage_core.capability(fn(request) {
      offstage_core.get_multipart_body(request, decoder.decoder)
    }),
  )
}

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                           Response                                            //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

/// The type representing a JSON response from the server
pub type JsonResponse(response) {
  JsonResponse(
    apply: fn(response) -> WispResponse,
    apply_when: fn(response, Bool, fn() -> WispResponse) -> WispResponse,
  )
}

pub fn json_response(
  spec: RouteSpecBuilder,
  code: Int,
  summary: String,
  encoder: encode.Encoder(response),
  next: fn(RouteSpecBuilder, RouteCapability(JsonResponse(response), object)) ->
    RouteSpec,
) -> RouteSpec {
  offstage_core.json_response_internal(
    spec,
    code,
    encoder,
    summary,
    JsonResponse,
    next,
  )
}

pub type BadRequestResponse {
  BadRequestResponse(
    apply: fn(String) -> WispResponse,
    apply_when: fn(String, Bool, fn() -> WispResponse) -> WispResponse,
  )
}

pub fn bad_request(
  spec: RouteSpecBuilder,
  next: fn(RouteSpecBuilder, RouteCapability(BadRequestResponse, object)) ->
    RouteSpec,
) -> RouteSpec {
  offstage_core.json_response_internal(
    spec,
    offstage_core.status_code.bad_request,
    offstage_core.error_response_serializer(option.Some("bad_request"))
      |> serialize.encoder()
      |> encode.map(offstage_core.ErrorResponse(
        status: "bad_request",
        reason: _,
      )),
    "Bad request",
    BadRequestResponse,
    next,
  )
}

pub type UnauthorizedResponse {
  UnauthorizedResponse(
    apply: fn(String) -> WispResponse,
    apply_when: fn(String, Bool, fn() -> WispResponse) -> WispResponse,
  )
}

pub fn unauthorized(
  spec: RouteSpecBuilder,
  next: fn(RouteSpecBuilder, RouteCapability(UnauthorizedResponse, object)) ->
    RouteSpec,
) -> RouteSpec {
  offstage_core.json_response_internal(
    spec,
    offstage_core.status_code.unauthorized,
    offstage_core.error_response_serializer(option.Some("unauthorized"))
      |> serialize.encoder()
      |> encode.map(offstage_core.ErrorResponse(
        status: "unauthorized",
        reason: _,
      )),
    "Unauthorized",
    UnauthorizedResponse,
    next,
  )
}

pub type NotFoundResponse {
  NotFoundResponse(
    apply: fn(String) -> WispResponse,
    apply_when: fn(String, Bool, fn() -> WispResponse) -> WispResponse,
  )
}

pub fn not_found(
  spec: RouteSpecBuilder,
  next: fn(RouteSpecBuilder, RouteCapability(NotFoundResponse, object)) ->
    RouteSpec,
) -> RouteSpec {
  offstage_core.json_response_internal(
    spec,
    offstage_core.status_code.not_found,
    offstage_core.error_response_serializer(option.Some("not_found"))
      |> serialize.encoder()
      |> encode.map(offstage_core.ErrorResponse(status: "not_found", reason: _)),
    "Not found",
    NotFoundResponse,
    next,
  )
}

pub type ConflictResponse {
  ConflictResponse(
    apply: fn(String) -> WispResponse,
    apply_when: fn(String, Bool, fn() -> WispResponse) -> WispResponse,
  )
}

pub fn conflict(
  spec: RouteSpecBuilder,
  next: fn(RouteSpecBuilder, RouteCapability(ConflictResponse, object)) ->
    RouteSpec,
) -> RouteSpec {
  offstage_core.json_response_internal(
    spec,
    offstage_core.status_code.conflict,
    offstage_core.error_response_serializer(option.Some("conflict"))
      |> serialize.encoder()
      |> encode.map(offstage_core.ErrorResponse(status: "conflict", reason: _)),
    "Conflict",
    ConflictResponse,
    next,
  )
}

pub type InternalServerErrorResponse {
  InternalServerErrorResponse(
    apply: fn(String) -> WispResponse,
    apply_when: fn(String, Bool, fn() -> WispResponse) -> WispResponse,
  )
}

pub fn internal_server_error(
  spec: RouteSpecBuilder,
  next: fn(
    RouteSpecBuilder,
    RouteCapability(InternalServerErrorResponse, object),
  ) -> RouteSpec,
) -> RouteSpec {
  offstage_core.json_response_internal(
    spec,
    offstage_core.status_code.internal_server_error,
    offstage_core.error_response_serializer(option.Some("internal_server_error"))
      |> serialize.encoder()
      |> encode.map(offstage_core.ErrorResponse(
        status: "internal_server_error",
        reason: _,
      )),
    "Internal server error",
    InternalServerErrorResponse,
    next,
  )
}

pub type ServiceUnavailableResponse {
  ServiceUnavailableResponse(
    apply: fn(String) -> WispResponse,
    apply_when: fn(String, Bool, fn() -> WispResponse) -> WispResponse,
  )
}

pub fn service_unavailable(
  spec: RouteSpecBuilder,
  next: fn(
    RouteSpecBuilder,
    RouteCapability(ServiceUnavailableResponse, object),
  ) -> RouteSpec,
) -> RouteSpec {
  offstage_core.json_response_internal(
    spec,
    offstage_core.status_code.service_unavailable,
    offstage_core.error_response_serializer(option.Some("service_unavailable"))
      |> serialize.encoder()
      |> encode.map(offstage_core.ErrorResponse(
        status: "service_unavailable",
        reason: _,
      )),
    "Service unavailable",
    ServiceUnavailableResponse,
    next,
  )
}

pub type TimeoutResponse {
  TimeoutResponse(
    apply: fn(String) -> WispResponse,
    apply_when: fn(String, Bool, fn() -> WispResponse) -> WispResponse,
  )
}

pub fn timeout(
  spec: RouteSpecBuilder,
  next: fn(RouteSpecBuilder, RouteCapability(TimeoutResponse, object)) ->
    RouteSpec,
) -> RouteSpec {
  offstage_core.json_response_internal(
    spec,
    offstage_core.status_code.timeout,
    offstage_core.error_response_serializer(option.Some("timeout"))
      |> serialize.encoder()
      |> encode.map(offstage_core.ErrorResponse(status: "timeout", reason: _)),
    "Timeout",
    TimeoutResponse,
    next,
  )
}

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                          Parameters                                           //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

fn path_parameter_internal(
  spec: RouteSpecBuilder,
  name: String,
  decoder: decode.Decoder(a),
  is_json: Bool,
  next: fn(RouteSpecBuilder, RouteCapability(a, object)) -> RouteSpec,
) -> RouteSpec {
  use spec, bad_request <- bad_request(spec)

  spec
  |> offstage_core.modify_spec(fn(scope) {
    use operation <- offstage_core.modify_operation(scope)
    use parameter <- openapi.operation.parameter(
      operation,
      name,
      openapi.ParameterInPath,
    )

    parameter
    |> openapi.parameter.required(True)
    |> openapi.parameter.set_schema(openapi_type.to_schema(decoder.doc()))
  })
  |> next(
    offstage_core.RouteCapability(fn(request, next) {
      use bad_request <- bad_request.get(request)

      let path_segments =
        openapi.openapi()
        |> spec.doc()
        |> offstage_core.openapi_scope_path()
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

      next(value)
    }),
  )
}

pub fn path_parameter(
  spec: RouteSpecBuilder,
  name: String,
  decoder: decode.Decoder(a),
  next: fn(RouteSpecBuilder, RouteCapability(a, object)) -> RouteSpec,
) -> RouteSpec {
  path_parameter_internal(spec, name, decoder, False, next)
}

pub fn json_path_parameter(
  spec: RouteSpecBuilder,
  name: String,
  decoder: decode.Decoder(a),
  next: fn(RouteSpecBuilder, RouteCapability(a, object)) -> RouteSpec,
) -> RouteSpec {
  path_parameter_internal(spec, name, decoder, True, next)
}

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                        Query Parameter                                        //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

fn query_parameter_internal(
  spec: RouteSpecBuilder,
  name: String,
  serializer: serialize.Serializer(a),
  default: option.Option(a),
  is_json: Bool,
  next: fn(RouteSpecBuilder, RouteCapability(a, object)) -> RouteSpec,
) -> RouteSpec {
  use spec, bad_request <- bad_request(spec)

  spec
  |> offstage_core.modify_spec(fn(scope) {
    use operation <- offstage_core.modify_operation(scope)
    use parameter <- openapi.operation.parameter(
      operation,
      name,
      openapi.ParameterInQuery,
    )

    parameter
    |> openapi.parameter.required(option.is_none(default))
    |> openapi.parameter.set_schema(openapi_type.to_schema(serializer.doc()))
  })
  |> next(
    offstage_core.RouteCapability(fn(request, next) {
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

      next(data)
    }),
  )
}

pub fn query_parameter(
  spec: RouteSpecBuilder,
  name: String,
  serializer: serialize.Serializer(a),
  default: option.Option(a),
  next: fn(RouteSpecBuilder, RouteCapability(a, object)) -> RouteSpec,
) -> RouteSpec {
  query_parameter_internal(spec, name, serializer, default, False, next)
}

pub fn json_query_parameter(
  spec: RouteSpecBuilder,
  name: String,
  serializer: serialize.Serializer(a),
  default: option.Option(a),
  next: fn(RouteSpecBuilder, RouteCapability(a, object)) -> RouteSpec,
) -> RouteSpec {
  query_parameter_internal(spec, name, serializer, default, True, next)
}

pub fn pagination(
  spec: RouteSpecBuilder,
  config: pagination.PaginationConfig(a, b, offstage_core.Connection),
  next: fn(RouteSpecBuilder, RouteCapability(a, object)) -> RouteSpec,
) -> RouteSpec {
  spec
  |> offstage_core.modify_spec(fn(scope) {
    use operation <- offstage_core.modify_operation(scope)
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
  |> next(
    offstage_core.capability(fn(request) {
      Ok(pagination.parse(config, request))
    }),
  )
}

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                            Runtime                                            //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

/// Verify if the given request segments match the route's segments.
/// Parameters like '{id}' will be treated as wildcards.
pub fn match_path_segment(
  request_segments: List(String),
  route_segments: List(String),
) -> Bool {
  use <- bool.guard(
    list.length(request_segments) != list.length(route_segments),
    return: False,
  )

  request_segments
  |> list.zip(route_segments)
  |> list.all(fn(entry) {
    let #(request_segment, route_segment) = entry
    case request_segment, route_segment {
      _, "{" <> content -> string.ends_with(content, "}")
      request_segment, route_segment if request_segment == route_segment -> True
      _, _ -> False
    }
  })
}

/// Build a route specification from the given builder functions.
pub fn build(
  spec: RouteSpecBuilder,
  builder: fn(Request) -> Result(object, WispResponse),
  route: fn(Request, object) -> WispResponse,
) -> RouteSpec {
  offstage_core.RouteSpec(
    doc: spec.doc,
    path: spec.path,
    method: spec.method,
    route: fn(request) {
      use object <- try(builder(request))
      route(request, object)
    },
  )
}

/// Route the request to the corresponding route based on the given specs.
pub fn router(
  openapi: openapi.OpenAPI,
  specs: List(RouteSpec),
  request: Request,
) -> WispResponse {
  let specs = [
    offstage_core.RouteSpec(
      path: "/openapi",
      method: http.Get,
      doc: fn(doc) { offstage_core.create_scope(doc, http.Get, "/openapi") },
      route: fn(_) {
        offstage_core.ok()
        |> offstage_core.json_body(
          openapi
          |> list.fold(specs, _, fn(openapi, spec) { doc(spec, openapi) })
          |> openapi.to_spec()
          |> spec.to_json(),
        )
      },
    ),
    ..specs
  ]

  let request_segments = request.path_segments(request)

  let matched_routes =
    specs
    |> list.filter(fn(spec) {
      spec.path
      |> uri.path_segments()
      |> match_path_segment(request_segments, _)
    })

  case matched_routes {
    [] -> offstage_core.not_found("Route not found!")
    _ ->
      list.find(matched_routes, fn(spec) { spec.method == request.method })
      |> result.map(fn(spec) { spec.route(request) })
      |> result.unwrap(
        wisp.method_not_allowed(
          list.map(matched_routes, fn(spec) { spec.method }),
        ),
      )
  }
}
