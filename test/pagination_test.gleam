import backstage/pagination
import dynamic/serialize
import garanti.{type Suite, Suite, Test}
import garanti/expect
import gleam/http
import gleam/time/calendar
import gleam/time/timestamp
import wisp/simulate

pub fn simple_pagination_suite() -> Suite {
  let default_page = 1
  let default_per_page = 10
  Suite("simple pagination", [
    Test("without pagination parameters", fn() {
      let request = simulate.browser_request(http.Get, "/book")

      pagination.simple()
      |> pagination.set_default_page(default_page)
      |> pagination.set_default_per_page(default_per_page)
      |> pagination.parse(request)
      |> expect.to_be_equal(pagination.Pagination(
        page: default_page,
        per_page: default_per_page,
      ))
    }),
    Test("with pagination parameters", fn() {
      let request =
        simulate.browser_request(http.Get, "/book?page=2&per_page=5")

      pagination.simple()
      |> pagination.set_default_page(default_page)
      |> pagination.set_default_per_page(default_per_page)
      |> pagination.parse(request)
      |> expect.to_be_equal(pagination.Pagination(page: 2, per_page: 5))
    }),
  ])
}

pub fn after_pagination_suite() -> Suite {
  let default_after = timestamp.unix_epoch
  let default_per_page = 10
  Suite("after pagination", [
    Test("without pagination parameters", fn() {
      let request = simulate.browser_request(http.Get, "/book")

      pagination.after(
        default: default_after,
        serializer: serialize.timestamp(),
      )
      |> pagination.set_default_per_page(default_per_page)
      |> pagination.parse(request)
      |> expect.to_be_equal(pagination.AfterPagination(
        after: default_after,
        per_page: default_per_page,
      ))
    }),
    Test("with pagination parameters", fn() {
      let request =
        simulate.browser_request(
          http.Get,
          "/book?after=2026-01-01T00:00:00Z&per_page=5",
        )

      pagination.after(
        default: default_after,
        serializer: serialize.timestamp(),
      )
      |> pagination.set_default_per_page(default_per_page)
      |> pagination.parse(request)
      |> expect.to_be_equal(pagination.AfterPagination(
        after: timestamp.from_calendar(
          date: calendar.Date(2026, calendar.January, 1),
          time: calendar.TimeOfDay(0, 0, 0, 0),
          offset: calendar.utc_offset,
        ),
        per_page: 5,
      ))
    }),
  ])
}

pub fn before_pagination_suite() -> Suite {
  let default_before = timestamp.unix_epoch
  let default_per_page = 10
  Suite("before pagination", [
    Test("without pagination parameters", fn() {
      let request = simulate.browser_request(http.Get, "/book")

      pagination.before(
        default: default_before,
        serializer: serialize.timestamp(),
      )
      |> pagination.set_default_per_page(default_per_page)
      |> pagination.parse(request)
      |> expect.to_be_equal(pagination.BeforePagination(
        before: default_before,
        per_page: default_per_page,
      ))
    }),
    Test("with pagination parameters", fn() {
      let request =
        simulate.browser_request(
          http.Get,
          "/book?before=2026-01-01T00:00:00Z&per_page=5",
        )

      pagination.before(
        default: default_before,
        serializer: serialize.timestamp(),
      )
      |> pagination.set_default_per_page(default_per_page)
      |> pagination.parse(request)
      |> expect.to_be_equal(pagination.BeforePagination(
        before: timestamp.from_calendar(
          date: calendar.Date(2026, calendar.January, 1),
          time: calendar.TimeOfDay(0, 0, 0, 0),
          offset: calendar.utc_offset,
        ),
        per_page: 5,
      ))
    }),
  ])
}
