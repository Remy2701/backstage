import backstage/backstage_core
import backstage/multipart
import dynamic/serialize
import garanti.{type Suite, Suite, Test}
import garanti/expect
import gleam/http
import gleam/http/request
import gleam/time/calendar
import gleam/time/timestamp
import wisp/simulate

type Book {
  Book(
    author: String,
    title: String,
    pages: Int,
    published_on: timestamp.Timestamp,
    cover: BitArray,
  )
}

pub fn multipart_body_suite() -> Suite {
  Suite("multipart body", [
    Test("multipart body with file", fn() {
      let file_content = <<"fake file content">>
      let request =
        simulate.browser_request(http.Post, "/book")
        |> simulate.multipart_body(
          [
            #("author", "J.K. Rowling"),
            #("title", "Harry Potter and the Philosopher's Stone"),
            #("pages", "223"),
            #("published_on", "1997-06-26T00:00:00Z"),
          ],
          [
            #(
              "cover",
              simulate.FileUpload("cover.jpg", "image/jpeg", file_content),
            ),
          ],
        )
        |> request.map(backstage_core.WispConnection)

      let body =
        backstage_core.get_multipart_body(
          request,
          serialize.object(fn(context) {
            use context, author <- serialize.field(
              context,
              "author",
              serialize.string(),
              fn(book: Book) { book.author },
            )
            use context, title <- serialize.field(
              context,
              "title",
              serialize.string(),
              fn(book: Book) { book.title },
            )
            use context, pages <- serialize.field(
              context,
              "pages",
              multipart.json_string_of(serialize.int()),
              fn(book: Book) { book.pages },
            )
            use context, published_on <- serialize.field(
              context,
              "published_on",
              multipart.json_string_of(serialize.timestamp()),
              fn(book: Book) { book.published_on },
            )
            use context, cover <- serialize.field(
              context,
              "cover",
              multipart.uploaded_file(),
              fn(book: Book) { book.cover },
            )

            serialize.build(
              context,
              Book(author, title, pages, published_on, cover),
            )
          }).decoder,
        )

      body
      |> expect.to_be_ok_then(fn(book) {
        book
        |> expect.to_be_equal(Book(
          author: "J.K. Rowling",
          title: "Harry Potter and the Philosopher's Stone",
          pages: 223,
          published_on: timestamp.from_calendar(
            date: calendar.Date(year: 1997, month: calendar.June, day: 26),
            time: calendar.TimeOfDay(0, 0, 0, 0),
            offset: calendar.utc_offset,
          ),
          cover: file_content,
        ))
      })
    }),
  ])
}
