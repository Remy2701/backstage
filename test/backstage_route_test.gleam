import backstage
import backstage/backstage_core
import backstage/pagination
import dynamic/serialize
import garanti.{type Suite, Suite, Test}
import gleam/http
import gleam/int
import gleam/json
import gleam/list
import openapi/openapi
import use_expect
import wisp
import wisp/simulate

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                         GET /version                                          //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

type GetVersionContext {
  GetVersionContext(json_response: backstage.JsonResponse(String))
}

pub fn get_version_route_test_suite() -> Suite {
  let spec = {
    let spec =
      backstage.get("/version")
      |> backstage.tag("Core")
      |> backstage.summary("Get the version of the API")

    use spec, json_response <- backstage.json_response(
      spec,
      200,
      "Version number",
      serialize.encoder(serialize.string()),
    )

    backstage.build(
      spec,
      fn(request) {
        use json_response <- json_response.get(request)

        Ok(GetVersionContext(json_response:))
      },
      fn(_, context) { context.json_response.apply("1.0.0") },
    )
  }

  Suite("GET /version", [
    Test("generated openapi docs", fn() {
      let doc =
        spec
        |> backstage.doc(openapi.openapi())

      use path <- use_expect.find(doc.paths, fn(path) {
        path.path == "/version"
      })

      use get <- use_expect.some(path.get, "get")
      use description <- use_expect.some(get.summary, "summary")
      use <- use_expect.equal(description, "Get the version of the API")
      use <- use_expect.contain(get.tags, "Core")

      use response <- use_expect.key_find(get.responses, 200)
      use <- use_expect.empty(get.parameters)
      use <- use_expect.empty(get.security)
      use <- use_expect.none(get.request_body)

      case response {
        openapi.Value(response) -> {
          use _ <- use_expect.key_find(response.content, "application/json")
          use_expect.pass()
        }
        openapi.Ref(_) -> use_expect.fail("openapi.Ref", "openapi.Value")
      }
    }),
    Test("http response", fn() {
      let response =
        simulate.browser_request(http.Get, "/version")
        |> backstage_core.from_wisp_request()
        |> spec.route()

      use <- use_expect.equal(response.status, 200)
      use <- use_expect.equal(
        response.body,
        json.string("1.0.0") |> json.to_string() |> wisp.Text,
      )

      use_expect.pass()
    }),
  ])
}

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                           GET /book                                           //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

type Book {
  Book(name: String, author: String)
}

fn book_serializer() -> serialize.Serializer(Book) {
  use context <- serialize.object()
  use context, name <- serialize.field(
    context,
    "name",
    serialize.string(),
    fn(book: Book) { book.name },
  )
  use context, author <- serialize.field(
    context,
    "author",
    serialize.string(),
    fn(book: Book) { book.author },
  )

  serialize.build(context, Book(name:, author:))
}

type GetBookContext {
  GetBookContext(
    pagination: pagination.Pagination,
    json_response: backstage.JsonResponse(List(Book)),
  )
}

pub fn get_book_route_test_suite() -> Suite {
  let spec = {
    let spec =
      backstage.get("/book")
      |> backstage.tag("Book")
      |> backstage.summary("Get the paginated list of books")

    use spec, pagination <- backstage.pagination(
      spec,
      pagination.simple() |> pagination.set_default_per_page(5),
    )

    use spec, json_response <- backstage.json_response(
      spec,
      200,
      "Paginated list of books",
      serialize.encoder(serialize.list(book_serializer())),
    )

    backstage.build(
      spec,
      fn(request) {
        use json_response <- json_response.get(request)
        use pagination <- pagination.get(request)

        Ok(GetBookContext(json_response:, pagination:))
      },
      fn(_, context) {
        let books =
          int.range(0, context.pagination.per_page, [], fn(acc, index) {
            [
              Book(
                name: "Book "
                  <> int.to_string(
                  index
                  + { context.pagination.page - 1 }
                  * context.pagination.per_page
                  + 1,
                ),
                author: "Author",
              ),
              ..acc
            ]
          })
          |> list.reverse()

        context.json_response.apply(books)
      },
    )
  }

  Suite("GET /book", [
    Test("generated openapi docs", fn() {
      let doc =
        spec
        |> backstage.doc(openapi.openapi())

      use path <- use_expect.find(doc.paths, fn(path) { path.path == "/book" })

      use get <- use_expect.some(path.get, "get")
      use description <- use_expect.some(get.summary, "summary")
      use <- use_expect.equal(description, "Get the paginated list of books")
      use <- use_expect.contain(get.tags, "Book")

      use response <- use_expect.key_find(get.responses, 200)
      use <- use_expect.equivalent(
        get.parameters
          |> list.map(fn(parameter) {
            case parameter {
              openapi.Ref(ref) -> ref
              openapi.Value(parameter) -> parameter.name
            }
          }),
        ["page", "per_page"],
      )
      use <- use_expect.empty(get.security)
      use <- use_expect.none(get.request_body)

      case response {
        openapi.Value(response) -> {
          use _ <- use_expect.key_find(response.content, "application/json")
          use_expect.pass()
        }
        openapi.Ref(_) -> use_expect.fail("openapi.Ref", "openapi.Value")
      }
    }),
    Test("base http response", fn() {
      let response =
        simulate.browser_request(http.Get, "/book")
        |> backstage_core.from_wisp_request()
        |> spec.route()

      use <- use_expect.equal(response.status, 200)
      use <- use_expect.equal(
        response.body,
        wisp.Text(
          [
            Book(name: "Book 1", author: "Author"),
            Book(name: "Book 2", author: "Author"),
            Book(name: "Book 3", author: "Author"),
            Book(name: "Book 4", author: "Author"),
            Book(name: "Book 5", author: "Author"),
          ]
          |> serialize.encode_json(serialize.list(book_serializer()))
          |> json.to_string(),
        ),
      )

      use_expect.pass()
    }),
    Test("http response with pagination", fn() {
      let response =
        simulate.browser_request(http.Get, "/book?page=2&per_page=3")
        |> backstage_core.from_wisp_request()
        |> spec.route()

      use <- use_expect.equal(response.status, 200)
      use <- use_expect.equal(
        response.body,
        wisp.Text(
          [
            Book(name: "Book 4", author: "Author"),
            Book(name: "Book 5", author: "Author"),
            Book(name: "Book 6", author: "Author"),
          ]
          |> serialize.encode_json(serialize.list(book_serializer()))
          |> json.to_string(),
        ),
      )

      use_expect.pass()
    }),
  ])
}

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                           POST /book                                           //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

type PostBookContext {
  PostBookContext(body: Book, json_response: backstage.JsonResponse(Book))
}

pub fn post_book_route_test_suite() -> Suite {
  let spec = {
    let spec =
      backstage.post("/book")
      |> backstage.tag("Book")
      |> backstage.summary("Create a new book")

    use spec, body <- backstage.json_body(
      spec,
      serialize.decoder(book_serializer()),
    )

    use spec, json_response <- backstage.json_response(
      spec,
      200,
      "Paginated list of books",
      serialize.encoder(book_serializer()),
    )

    backstage.build(
      spec,
      fn(request) {
        use json_response <- json_response.get(request)
        use body <- body.get(request)

        Ok(PostBookContext(json_response:, body:))
      },
      fn(_, context) { context.json_response.apply(context.body) },
    )
  }

  Suite("GET /book", [
    Test("generated openapi docs", fn() {
      let doc =
        spec
        |> backstage.doc(openapi.openapi())

      use path <- use_expect.find(doc.paths, fn(path) { path.path == "/book" })

      use post <- use_expect.some(path.post, "post")
      use description <- use_expect.some(post.summary, "summary")
      use <- use_expect.equal(description, "Create a new book")
      use <- use_expect.contain(post.tags, "Book")

      use response <- use_expect.key_find(post.responses, 200)
      use <- use_expect.empty(post.parameters)
      use <- use_expect.empty(post.security)
      use body <- use_expect.some(post.request_body, "request_body")
      use _ <- use_expect.key_find(body.content, "application/json")

      case response {
        openapi.Value(response) -> {
          use _ <- use_expect.key_find(response.content, "application/json")
          use_expect.pass()
        }
        openapi.Ref(_) -> use_expect.fail("openapi.Ref", "openapi.Value")
      }
    }),
    Test("base http response", fn() {
      let book = Book(name: "My book", author: "Myself")
      let response =
        simulate.browser_request(http.Post, "/book")
        |> simulate.json_body(serialize.encode_json(book, book_serializer()))
        |> backstage_core.from_wisp_request()
        |> spec.route()

      use <- use_expect.equal(response.status, 200)
      use <- use_expect.equal(
        response.body,
        wisp.Text(
          book
          |> serialize.encode_json(book_serializer())
          |> json.to_string(),
        ),
      )

      use_expect.pass()
    }),
  ])
}
