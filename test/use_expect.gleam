import expect_plus
import garanti
import garanti/expect
import gleam/option

pub fn pass() -> garanti.AssertionResult {
  garanti.Pass
}

pub fn fail(actual: String, expected: String) -> garanti.AssertionResult {
  garanti.Fail("Expected " <> expected <> " but got " <> actual, [
    garanti.Actual(actual),
    garanti.Expected(expected),
  ])
}

fn try(
  result: garanti.AssertionResult,
  next: fn() -> garanti.AssertionResult,
) -> garanti.AssertionResult {
  case result {
    garanti.Pass -> next()
    other -> other
  }
}

pub fn equal(
  actual: a,
  expected: a,
  next: fn() -> garanti.AssertionResult,
) -> garanti.AssertionResult {
  try(expect.to_be_equal(actual, expected), next)
}

pub fn find(
  actual: List(a),
  predicate: fn(a) -> Bool,
  next: fn(a) -> garanti.AssertionResult,
) -> garanti.AssertionResult {
  expect_plus.find_then(actual, predicate, next)
}

pub fn key_find(
  actual: List(#(a, b)),
  key: a,
  next: fn(b) -> garanti.AssertionResult,
) -> garanti.AssertionResult {
  expect_plus.key_find_then(actual, key, next)
}

pub fn some(
  actual: option.Option(a),
  context: String,
  next: fn(a) -> garanti.AssertionResult,
) -> garanti.AssertionResult {
  expect_plus.to_be_some_then(actual, context, next)
}

pub fn none(
  actual: option.Option(a),
  next: fn() -> garanti.AssertionResult,
) -> garanti.AssertionResult {
  try(expect.to_be_none(actual), next)
}

pub fn contain(
  actual: List(a),
  value: a,
  next: fn() -> garanti.AssertionResult,
) -> garanti.AssertionResult {
  try(expect.to_contain(actual, value), next)
}

pub fn empty(
  actual: List(a),
  next: fn() -> garanti.AssertionResult,
) -> garanti.AssertionResult {
  try(expect.to_be_empty(actual), next)
}

pub fn equivalent(
  actual: List(a),
  expected: List(a),
  next: fn() -> garanti.AssertionResult,
) -> garanti.AssertionResult {
  try(expect.to_be_equivalent(actual, expected), next)
}
