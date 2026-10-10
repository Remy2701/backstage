import dynamic/serialize
import gleam/dynamic
import gleam/http/request.{type Request}
import gleam/int
import gleam/json
import gleam/list
import gleam/result

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                          Pagination                                           //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

/// Represents pagination parameters for API requests.
/// `page` is the current page number (starting from 1).
/// `per_page` is the number of items to return per page.
pub type Pagination {
  Pagination(page: Int, per_page: Int)
}

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                       After Pagination                                        //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

pub type AfterPagination(a) {
  AfterPagination(after: a, per_page: Int)
}

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                       Before Pagination                                       //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

pub type BeforePagination(a) {
  BeforePagination(before: a, per_page: Int)
}

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                         Configuration                                         //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

pub type PaginationConfig(a, b, c) {
  SimplePaginationConfig(
    default_page: Int,
    default_per_page: Int,
    max_per_page: Int,
    parser: fn(PaginationConfig(a, b, c), Request(c)) -> a,
  )
  AfterPaginationConfig(
    default_after: b,
    after_serializer: serialize.Serializer(b),
    is_json: Bool,
    default_per_page: Int,
    max_per_page: Int,
    parser: fn(PaginationConfig(a, b, c), Request(c)) -> a,
  )
  BeforePaginationConfig(
    default_before: b,
    before_serializer: serialize.Serializer(b),
    is_json: Bool,
    default_per_page: Int,
    max_per_page: Int,
    parser: fn(PaginationConfig(a, b, c), Request(c)) -> a,
  )
}

pub fn simple() -> PaginationConfig(Pagination, Nil, c) {
  SimplePaginationConfig(
    default_page: 1,
    default_per_page: 10,
    max_per_page: 100,
    parser: fn(self, request) {
      let assert SimplePaginationConfig(
        default_per_page:,
        default_page:,
        max_per_page:,
        ..,
      ) = self
      parse_simple(default_page:, default_per_page:, max_per_page:, request:)
    },
  )
}

pub fn after(
  default default: b,
  serializer serializer: serialize.Serializer(b),
) -> PaginationConfig(AfterPagination(b), b, c) {
  AfterPaginationConfig(
    default_after: default,
    after_serializer: serializer,
    is_json: False,
    default_per_page: 10,
    max_per_page: 100,
    parser: fn(self, request) {
      let assert AfterPaginationConfig(
        default_after:,
        after_serializer:,
        is_json:,
        default_per_page:,
        max_per_page:,
        ..,
      ) = self
      parse_after(
        is_json:,
        default_after:,
        after_serializer:,
        default_per_page:,
        max_per_page:,
        request:,
      )
    },
  )
}

pub fn before(
  default default: b,
  serializer serializer: serialize.Serializer(b),
) -> PaginationConfig(BeforePagination(b), b, c) {
  BeforePaginationConfig(
    default_before: default,
    before_serializer: serializer,
    is_json: False,
    default_per_page: 10,
    max_per_page: 100,
    parser: fn(self, request) {
      let assert BeforePaginationConfig(
        default_before:,
        before_serializer:,
        is_json:,
        default_per_page:,
        max_per_page:,
        ..,
      ) = self
      parse_before(
        is_json:,
        default_before:,
        before_serializer:,
        default_per_page:,
        max_per_page:,
        request:,
      )
    },
  )
}

pub fn as_json(config: PaginationConfig(a, b, c)) -> PaginationConfig(a, b, c) {
  case config {
    SimplePaginationConfig(..) -> config
    AfterPaginationConfig(..) -> AfterPaginationConfig(..config, is_json: True)
    BeforePaginationConfig(..) ->
      BeforePaginationConfig(..config, is_json: True)
  }
}

pub fn set_default_per_page(
  config: PaginationConfig(a, b, c),
  default_per_page: Int,
) -> PaginationConfig(a, b, c) {
  case config {
    SimplePaginationConfig(..) ->
      SimplePaginationConfig(..config, default_per_page: default_per_page)
    AfterPaginationConfig(..) ->
      AfterPaginationConfig(..config, default_per_page: default_per_page)
    BeforePaginationConfig(..) ->
      BeforePaginationConfig(..config, default_per_page: default_per_page)
  }
}

pub fn set_max_per_page(
  config: PaginationConfig(a, b, c),
  max_per_page: Int,
) -> PaginationConfig(a, b, c) {
  case config {
    SimplePaginationConfig(..) ->
      SimplePaginationConfig(..config, max_per_page: max_per_page)
    AfterPaginationConfig(..) ->
      AfterPaginationConfig(..config, max_per_page: max_per_page)
    BeforePaginationConfig(..) ->
      BeforePaginationConfig(..config, max_per_page: max_per_page)
  }
}

pub fn set_default_page(
  config: PaginationConfig(a, b, c),
  default_page: Int,
) -> PaginationConfig(a, b, c) {
  case config {
    SimplePaginationConfig(..) ->
      SimplePaginationConfig(..config, default_page: default_page)
    AfterPaginationConfig(..) -> config
    BeforePaginationConfig(..) -> config
  }
}

fn parse_simple(
  default_page default_page: Int,
  default_per_page default_per_page: Int,
  max_per_page max_per_page: Int,
  request request: Request(c),
) -> Pagination {
  let query = request.get_query(request) |> result.unwrap([])

  let page =
    list.key_find(query, "page")
    |> result.map(fn(s) { int.parse(s) })
    |> result.flatten()
    |> result.unwrap(default_page)
    |> int.max(1)

  let per_page =
    list.key_find(query, "per_page")
    |> result.map(fn(s) { int.parse(s) })
    |> result.flatten()
    |> result.unwrap(default_per_page)
    |> int.clamp(1, max_per_page)

  Pagination(page: page, per_page: per_page)
}

fn parse_after(
  is_json is_json: Bool,
  default_after default_after: a,
  after_serializer after_serializer: serialize.Serializer(a),
  default_per_page default_per_page: Int,
  max_per_page max_per_page: Int,
  request request: Request(c),
) -> AfterPagination(a) {
  let query = request.get_query(request) |> result.unwrap([])

  let after =
    list.key_find(query, "after")
    |> result.map(fn(s) {
      case is_json {
        True ->
          json.parse(s, after_serializer.decoder) |> result.replace_error(Nil)
        False ->
          serialize.decode(dynamic.string(s), after_serializer)
          |> result.replace_error(Nil)
      }
    })
    |> result.flatten()
    |> result.unwrap(default_after)

  let per_page =
    list.key_find(query, "per_page")
    |> result.map(fn(s) { int.parse(s) })
    |> result.flatten()
    |> result.unwrap(default_per_page)
    |> int.clamp(1, max_per_page)

  AfterPagination(after: after, per_page: per_page)
}

fn parse_before(
  is_json is_json: Bool,
  default_before default_before: a,
  before_serializer before_serializer: serialize.Serializer(a),
  default_per_page default_per_page: Int,
  max_per_page max_per_page: Int,
  request request: Request(c),
) -> BeforePagination(a) {
  let query = request.get_query(request) |> result.unwrap([])

  let before =
    list.key_find(query, "before")
    |> result.map(fn(s) {
      case is_json {
        True ->
          json.parse(s, before_serializer.decoder) |> result.replace_error(Nil)
        False ->
          serialize.decode(dynamic.string(s), before_serializer)
          |> result.replace_error(Nil)
      }
    })
    |> result.flatten()
    |> result.unwrap(default_before)

  let per_page =
    list.key_find(query, "per_page")
    |> result.map(fn(s) { int.parse(s) })
    |> result.flatten()
    |> result.unwrap(default_per_page)
    |> int.clamp(1, max_per_page)

  BeforePagination(before: before, per_page: per_page)
}

pub fn parse(config: PaginationConfig(a, b, c), request: Request(c)) -> a {
  case config {
    SimplePaginationConfig(parser:, ..) -> parser(config, request)
    AfterPaginationConfig(parser:, ..) -> parser(config, request)
    BeforePaginationConfig(parser:, ..) -> parser(config, request)
  }
}
