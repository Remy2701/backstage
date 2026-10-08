import garanti
import garanti/shared/list_ext
import gleam/list
import gleam/option
import gleam/string
import pretty_diff

pub fn start_with(actual: String, prefix: String) -> garanti.AssertionResult {
  case string.starts_with(actual, prefix) {
    True -> garanti.Pass
    False ->
      garanti.Fail(
        "Expected string to start start with '"
          <> prefix
          <> "' but found '"
          <> actual
          <> "'",
        [
          garanti.Diff(pretty_diff.from(
            string.slice(actual, 0, string.length(prefix)),
            prefix,
          )),
        ],
      )
  }
}

pub fn find_then(
  actual: List(a),
  predicate: fn(a) -> Bool,
  then: fn(a) -> garanti.AssertionResult,
) -> garanti.AssertionResult {
  let result = list.find(actual, predicate)

  case result {
    Ok(value) -> then(value)
    Error(_) ->
      garanti.Fail("Expected list to contain a value matching the predicate.", [
        garanti.Actual(list_ext.describe(actual, 10)),
        garanti.Expected("a value matching the predicate"),
      ])
  }
}

pub fn key_find_then(
  actual: List(#(a, b)),
  key: a,
  then: fn(b) -> garanti.AssertionResult,
) -> garanti.AssertionResult {
  let result = list.key_find(actual, key)

  case result {
    Ok(value) -> then(value)
    Error(_) ->
      garanti.Fail(
        "Expected list to contain a value with key '"
          <> string.inspect(key)
          <> "'",
        [
          garanti.Actual(list_ext.describe(actual, 10)),
          garanti.Expected("a value with key '" <> string.inspect(key) <> "'"),
        ],
      )
  }
}

pub fn to_be_some_then(
  actual: option.Option(a),
  context: String,
  then: fn(a) -> garanti.AssertionResult,
) -> garanti.AssertionResult {
  case actual {
    option.Some(res) -> then(res)
    option.None ->
      garanti.Fail("Expected " <> context <> " to be Some but it was None", [
        garanti.Actual("None"),
        garanti.Expected("Some"),
      ])
  }
}
