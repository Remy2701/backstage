import expect_plus
import garanti.{type Suite, Suite, Test}
import garanti/expect
import gleam/http
import gleam/json
import offstage/offstage_core
import wisp/simulate

pub fn get_content_type_test_suite() -> Suite {
  Suite("get_content_type_test", [
    Test("text/plain", fn() {
      simulate.browser_request(http.Get, "/")
      |> simulate.string_body("Some content")
      |> offstage_core.from_wisp_request()
      |> offstage_core.get_content_type()
      |> expect.to_be_ok_then(fn(content_type) {
        content_type |> expect.to_be_equal("text/plain")
      })
    }),
    Test("application/json", fn() {
      simulate.browser_request(http.Get, "/")
      |> simulate.json_body(json.object([]))
      |> offstage_core.from_wisp_request()
      |> offstage_core.get_content_type()
      |> expect.to_be_ok_then(fn(content_type) {
        content_type |> expect.to_be_equal("application/json")
      })
    }),
    Test("application/x-www-form-urlencoded", fn() {
      simulate.browser_request(http.Get, "/")
      |> simulate.form_body([])
      |> offstage_core.from_wisp_request()
      |> offstage_core.get_content_type()
      |> expect.to_be_ok_then(fn(content_type) {
        content_type |> expect.to_be_equal("application/x-www-form-urlencoded")
      })
    }),
    Test("multipart/form-data", fn() {
      simulate.browser_request(http.Get, "/")
      |> simulate.multipart_body([], [])
      |> offstage_core.from_wisp_request()
      |> offstage_core.get_content_type()
      |> expect.to_be_ok_then(expect_plus.start_with(
        _,
        "multipart/form-data; boundary=",
      ))
    }),
  ])
}
