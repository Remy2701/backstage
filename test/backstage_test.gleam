import backstage
import garanti.{type Suite, Suite, Test}
import garanti/expect
import garanti/runner
import gleam/http
import gleam/http/request
import gleam/uri
import wisp/simulate

pub fn main() -> Nil {
  runner.run(garanti.Info)
}

pub fn match_path_segment_test_suite() -> Suite {
  Suite("match_path_segment", [
    Test("simple", fn() {
      backstage.match_path_segment(
        request.path_segments(simulate.browser_request(http.Get, "/log")),
        uri.path_segments("/log"),
      )
      |> expect.to_be_equal(True)
    }),
    Test("with_parameter", fn() {
      backstage.match_path_segment(
        request.path_segments(simulate.browser_request(http.Get, "/user/123")),
        uri.path_segments("/user/{id}"),
      )
      |> expect.to_be_equal(True)
    }),
  ])
}
