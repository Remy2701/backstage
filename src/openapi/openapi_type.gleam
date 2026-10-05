import dynamic/spec
import gleam/list
import gleam/option.{type Option, None, Some}
import openapi/openapi

/// A type representing the various OpenAPI data types and their associated metadata.
pub type OpenAPIType {
  String(
    format: Option(String),
    default: Option(spec.Spec),
    examples: List(spec.Spec),
    pattern: Option(String),
    enum: List(String),
  )
  Integer(
    format: Option(String),
    default: Option(spec.Spec),
    examples: List(spec.Spec),
  )
  Number(
    format: Option(String),
    default: Option(spec.Spec),
    examples: List(spec.Spec),
  )
  Boolean(
    format: Option(String),
    default: Option(spec.Spec),
    examples: List(spec.Spec),
  )
  Array(
    format: Option(String),
    default: Option(spec.Spec),
    examples: List(spec.Spec),
    items: Option(OpenAPIType),
  )
  Object(
    format: Option(String),
    default: Option(spec.Spec),
    examples: List(spec.Spec),
    properties: List(ObjectProperty),
  )
  Null
  Option(of: OpenAPIType)
}

pub type ObjectProperty {
  ObjectProperty(name: String, type_: OpenAPIType, required: Bool)
}

/// Specify the format for an OpenAPI type.
pub fn format(type_: OpenAPIType, format fmt: String) -> OpenAPIType {
  case type_ {
    String(..) -> String(..type_, format: Some(fmt))
    Integer(..) -> Integer(..type_, format: Some(fmt))
    Number(..) -> Number(..type_, format: Some(fmt))
    Boolean(..) -> Boolean(..type_, format: Some(fmt))
    Array(..) -> Array(..type_, format: Some(fmt))
    Object(..) -> Object(..type_, format: Some(fmt))
    Null -> Null
    Option(of) -> Option(format(of, fmt))
  }
}

/// Specify the default value for an OpenAPI type.
pub fn default(type_: OpenAPIType, default dflt: spec.Spec) -> OpenAPIType {
  case type_ {
    String(..) -> String(..type_, default: Some(dflt))
    Integer(..) -> Integer(..type_, default: Some(dflt))
    Number(..) -> Number(..type_, default: Some(dflt))
    Boolean(..) -> Boolean(..type_, default: Some(dflt))
    Array(..) -> Array(..type_, default: Some(dflt))
    Object(..) -> Object(..type_, default: Some(dflt))
    Null -> Null
    Option(of) -> Option(default(of, dflt))
  }
}

/// Specify an example value for an OpenAPI type.
pub fn example(type_: OpenAPIType, example ex: spec.Spec) -> OpenAPIType {
  case type_ {
    String(..) -> String(..type_, examples: list.append(type_.examples, [ex]))
    Integer(..) -> Integer(..type_, examples: list.append(type_.examples, [ex]))
    Number(..) -> Number(..type_, examples: list.append(type_.examples, [ex]))
    Boolean(..) -> Boolean(..type_, examples: list.append(type_.examples, [ex]))
    Array(..) -> Array(..type_, examples: list.append(type_.examples, [ex]))
    Object(..) -> Object(..type_, examples: list.append(type_.examples, [ex]))
    Null -> Null
    Option(of) -> Option(example(of, ex))
  }
}

/// Specify a pattern for an OpenAPI string type.
pub fn pattern(type_: OpenAPIType, pattern p: String) -> OpenAPIType {
  case type_ {
    String(..) -> String(..type_, pattern: Some(p))
    Option(of) -> Option(pattern(of, p))
    _ -> type_
  }
}

/// A string type with no specific format, default, pattern, examples, or enum.
pub fn string() -> OpenAPIType {
  String(format: None, default: None, pattern: None, examples: [], enum: [])
}

/// A string type with a predefined set of allowed values (enum).
pub fn string_enum(options: List(String)) -> OpenAPIType {
  String(
    format: None,
    default: None,
    pattern: None,
    examples: [],
    enum: options,
  )
}

/// An integer type with no specific format, default, or examples.
pub fn integer() -> OpenAPIType {
  Integer(format: None, default: None, examples: [])
}

/// A number type with no specific format, default, or examples.
pub fn number() -> OpenAPIType {
  Number(format: None, default: None, examples: [])
}

/// A boolean type with no specific format, default, or examples.
pub fn boolean() -> OpenAPIType {
  Boolean(format: None, default: None, examples: [])
}

/// An array type with no specific format, default, items, or examples.
pub fn untyped_array() -> OpenAPIType {
  Array(format: None, default: None, items: None, examples: [])
}

/// An array type with a specified item type and no specific format, default, or examples.
pub fn array(items: OpenAPIType) -> OpenAPIType {
  Array(format: None, default: None, items: Some(items), examples: [])
}

/// An object type with the given properties and no specific format, default, or examples.
pub fn object(properties: List(ObjectProperty)) -> OpenAPIType {
  Object(format: None, default: None, properties: properties, examples: [])
}

/// An optional type wrapping another OpenAPI type.
pub fn option(of: OpenAPIType) -> OpenAPIType {
  Option(of: of)
}

/// Convert the OpenAPI type to a list of schema type strings.
fn to_schema_type(type_: OpenAPIType) -> List(String) {
  case type_ {
    String(..) -> ["string"]
    Integer(..) -> ["integer"]
    Number(..) -> ["number"]
    Boolean(..) -> ["boolean"]
    Array(..) -> ["array"]
    Object(..) -> ["object"]
    Null -> ["null"]
    Option(of:) -> ["null", ..to_schema_type(of)]
  }
}

/// Get the format of the OpenAPI type, if any.
fn format_of(type_: OpenAPIType) -> Option(String) {
  case type_ {
    String(format:, ..) -> format
    Integer(format:, ..) -> format
    Number(format:, ..) -> format
    Boolean(format:, ..) -> format
    Array(format:, ..) -> format
    Object(format:, ..) -> format
    Null -> None
    Option(of:) -> format_of(of)
  }
}

/// Get the default value of the OpenAPI type, if any.
fn default_of(type_: OpenAPIType) -> Option(spec.Spec) {
  case type_ {
    String(default:, ..) -> default
    Integer(default:, ..) -> default
    Number(default:, ..) -> default
    Boolean(default:, ..) -> default
    Array(default:, ..) -> default
    Object(default:, ..) -> default
    Null -> None
    Option(of:) -> default_of(of)
  }
}

/// Get the examples of the OpenAPI type, if any.
fn examples_of(type_: OpenAPIType) -> List(spec.Spec) {
  case type_ {
    String(examples:, ..) -> examples
    Integer(examples:, ..) -> examples
    Number(examples:, ..) -> examples
    Boolean(examples:, ..) -> examples
    Array(examples:, ..) -> examples
    Object(examples:, ..) -> examples
    Null -> []
    Option(of:) -> examples_of(of)
  }
}

/// Convert the OpenAPI type to an OpenAPI schema.
pub fn to_schema(type_: OpenAPIType) -> openapi.Schema {
  openapi.Schema(
    type_: to_schema_type(type_),
    format: format_of(type_),
    default: default_of(type_),
    pattern: case type_ {
      String(pattern:, ..) -> pattern
      _ -> None
    },
    items: case type_ {
      Array(items:, ..) -> option.map(items, to_schema)
      _ -> None
    },
    properties: case type_ {
      Object(properties:, ..) ->
        properties
        |> list.map(fn(entry) { #(entry.name, to_schema(entry.type_)) })
      _ -> []
    },
    enum: case type_ {
      String(enum:, ..) -> enum
      _ -> []
    },
    required: case type_ {
      Object(properties:, ..) ->
        properties
        |> list.filter(fn(entry) { entry.required })
        |> list.map(fn(entry) { entry.name })
      _ -> []
    },
    examples: examples_of(type_),
  )
}
