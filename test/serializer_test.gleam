import dynamic/serialize
import dynamic/spec
import garanti.{type Suite, Suite, Test}
import garanti/expect
import gleam/dynamic
import gleam/option
import gleam/time/timestamp
import openapi/openapi_type

fn serializer_suite_of_with_dynamic(
  name: String,
  serializer: serialize.Serializer(t),
  doc: openapi_type.OpenAPIType,
  value: t,
  spec: spec.Spec,
  dynamic: dynamic.Dynamic,
) -> Suite {
  Suite(name, [
    Test("Verify doc", fn() {
      serializer.doc()
      |> expect.to_be_equal(doc)
    }),
    Test("Decode value", fn() {
      serialize.decode(dynamic, serializer)
      |> expect.to_be_ok_then(fn(value) { expect.to_be_equal(value, value) })
    }),
    Test("Encode value", fn() {
      serialize.encode(value, serializer)
      |> expect.to_be_equal(spec)
    }),
  ])
}

fn serializer_suite_of(
  name: String,
  serializer: serialize.Serializer(t),
  doc: openapi_type.OpenAPIType,
  value: t,
  spec: spec.Spec,
) -> Suite {
  serializer_suite_of_with_dynamic(
    name,
    serializer,
    doc,
    value,
    spec,
    spec.to_dynamic(spec),
  )
}

/// Test decoding of a string value.
pub fn serialize_string_suite() -> Suite {
  serializer_suite_of(
    "serialize_string_suite",
    serialize.string(),
    openapi_type.string(),
    "test",
    spec.String("test"),
  )
}

/// Test decoding of a int value.
pub fn serialize_int_suite() -> Suite {
  serializer_suite_of(
    "serialize_int_suite",
    serialize.int(),
    openapi_type.integer(),
    42,
    spec.Integer(42),
  )
}

/// Test decoding of a float value.
pub fn serialize_float_suite() -> Suite {
  serializer_suite_of(
    "serialize_float_suite",
    serialize.float(),
    openapi_type.number() |> openapi_type.format("double"),
    3.14,
    spec.Float(3.14),
  )
}

/// Test decoding of a boolean value.
pub fn serialize_bool_suite() -> Suite {
  serializer_suite_of(
    "serialize_bool_suite",
    serialize.bool(),
    openapi_type.boolean(),
    True,
    spec.Boolean(True),
  )
}

pub fn serialize_list_of_strings_suite() -> Suite {
  serializer_suite_of(
    "serialize_list_of_strings_suite",
    serialize.list(serialize.string()),
    openapi_type.array(openapi_type.string()),
    ["a", "b", "c"],
    spec.Array([spec.String("a"), spec.String("b"), spec.String("c")]),
  )
}

pub fn serialize_option_of_string_suite() -> Suite {
  serializer_suite_of(
    "serialize_option_of_string_suite",
    serialize.optional(serialize.string()),
    openapi_type.option(openapi_type.string()),
    option.Some("a"),
    spec.String("a"),
  )
}

pub fn serialize_option_of_string_as_none_suite() -> Suite {
  serializer_suite_of(
    "serialize_option_of_string_as_none_suite",
    serialize.optional(serialize.string()),
    openapi_type.option(openapi_type.string()),
    option.None,
    spec.Null,
  )
}

pub fn serialize_timestamp_suite() -> Suite {
  serializer_suite_of(
    "serialize_timestamp_suite",
    serialize.timestamp(),
    openapi_type.string() |> openapi_type.format("date-time"),
    timestamp.from_unix_seconds(1_234_567_890),
    spec.String("2009-02-13T23:31:30Z"),
  )
}

type Color {
  Red
  Green
  Blue
}

/// Test decoding of a string value.
pub fn serialize_string_enum_suite() -> Suite {
  serializer_suite_of(
    "serialize_string_enum_suite",
    serialize.string_enum([Red, Green, Blue], fn(color) {
      case color {
        Red -> "red"
        Green -> "green"
        Blue -> "blue"
      }
    }),
    openapi_type.string_enum(["red", "green", "blue"]),
    Red,
    spec.String("red"),
  )
}

type Person {
  Person(name: String, age: Int, is_student: Bool)
}

pub fn serialize_person_object_suite() -> Suite {
  serializer_suite_of(
    "serialize_person_object_suite",
    serialize.object(fn(context) {
      use context, name <- serialize.field(
        context,
        "name",
        serialize.string(),
        fn(person: Person) { person.name },
      )
      use context, age <- serialize.field(
        context,
        "age",
        serialize.int(),
        fn(person: Person) { person.age },
      )
      use context, is_student <- serialize.field(
        context,
        "is_student",
        serialize.bool(),
        fn(person: Person) { person.is_student },
      )

      serialize.build(context, Person(name:, age:, is_student:))
    }),
    openapi_type.object([
      #("name", openapi_type.string()),
      #("age", openapi_type.integer()),
      #("is_student", openapi_type.boolean()),
    ]),
    Person(name: "Alice", age: 30, is_student: True),
    spec.Object([
      #("name", spec.String("Alice")),
      #("age", spec.Integer(30)),
      #("is_student", spec.Boolean(True)),
    ]),
  )
}

pub fn serialize_person_object_optional_suite() -> Suite {
  serializer_suite_of_with_dynamic(
    "serialize_person_object_optional_suite",
    serialize.object(fn(context) {
      use context, name <- serialize.field(
        context,
        "name",
        serialize.string(),
        fn(person: Person) { person.name },
      )
      use context, age <- serialize.field(
        context,
        "age",
        serialize.int(),
        fn(person: Person) { person.age },
      )
      use context, is_student <- serialize.optional_field(
        context: context,
        name: "is_student",
        default: False,
        serializer: serialize.bool(),
        getter: fn(person: Person) { person.is_student },
      )

      serialize.build(context, Person(name:, age:, is_student:))
    }),
    openapi_type.object([
      #("name", openapi_type.string()),
      #("age", openapi_type.integer()),
      #("is_student", openapi_type.boolean()),
    ]),
    Person(name: "Alice", age: 30, is_student: True),
    spec.Object([
      #("name", spec.String("Alice")),
      #("age", spec.Integer(30)),
      #("is_student", spec.Boolean(True)),
    ]),
    dynamic.properties([
      #(dynamic.string("name"), dynamic.string("Alice")),
      #(dynamic.string("age"), dynamic.int(30)),
    ]),
  )
}
