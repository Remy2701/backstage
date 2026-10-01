import gleam/json.{type Json}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/pair
import taffy/value.{type YamlValue as Yaml} as yaml

/// A common specification type for representing JSON and YAML structures.
pub type Spec {
  String(value: String)
  Integer(value: Int)
  Float(value: Float)
  Boolean(value: Bool)
  Null
  Array(values: List(Spec))
  Object(properties: List(#(String, Spec)))
}

/// Creates a `Spec` representing a string value.
pub fn string(value: String) -> Spec {
  String(value)
}

/// Creates a `Spec` representing an integer value.
pub fn integer(value: Int) -> Spec {
  Integer(value)
}

/// Creates a `Spec` representing a float value.
pub fn float(value: Float) -> Spec {
  Float(value)
}

/// Creates a `Spec` representing a boolean value.
pub fn boolean(value: Bool) -> Spec {
  Boolean(value)
}

/// Creates a `Spec` representing a null value.
pub fn null() -> Spec {
  Null
}

/// Creates a `Spec` representing a nullable value.
pub fn nullable(value: Option(a), transformer: fn(a) -> Spec) -> Spec {
  case value {
    Some(v) -> transformer(v)
    None -> Null
  }
}

/// Creates a `Spec` representing an array of values.
pub fn array(values: List(Spec)) -> Spec {
  Array(values)
}

/// Creates a `Spec` representing an array of transformed values.
pub fn array_of(values: List(a), transformer: fn(a) -> Spec) -> Spec {
  Array(list.map(values, transformer))
}

/// Creates a `Spec` representing an object with the given properties.
pub fn object(properties: List(#(String, Spec))) -> Spec {
  Object(properties)
}

/// Creates a `Spec` representing an object with transformed properties.
pub fn object_of(
  values: List(a),
  transformer: fn(a) -> #(String, Spec),
) -> Spec {
  Object(list.map(values, transformer))
}

/// Creates a `Spec` representing an object from a list of key-value tuples, transforming the values.
pub fn object_of_tuple(
  values: List(#(String, a)),
  transformer: fn(a) -> Spec,
) -> Spec {
  Object(list.map(values, pair.map_second(_, transformer)))
}

/// Recursively omits `Null` values from a `Spec`.
pub fn omit_null(spec: Spec) -> Spec {
  case spec {
    Array(values:) -> Array(list.map(values, omit_null))
    Object(properties:) ->
      Object(
        list.filter(properties, fn(entry) { entry.1 != Null })
        |> list.map(pair.map_second(_, omit_null)),
      )
    _ -> spec
  }
}

/// Returns `option.None` if the list is empty, otherwise returns `option.Some` with the list.
pub fn none_if_empty(list: List(a)) -> Option(List(a)) {
  case list {
    [] -> None
    list -> Some(list)
  }
}

/// Converts a `Spec` to a JSON value.
pub fn to_json(spec: Spec) -> Json {
  case spec {
    String(value:) -> json.string(value)
    Integer(value:) -> json.int(value)
    Float(value:) -> json.float(value)
    Boolean(value:) -> json.bool(value)
    Null -> json.null()
    Array(values:) -> json.array(values, to_json)
    Object(properties:) ->
      json.object(list.map(properties, pair.map_second(_, to_json)))
  }
}

/// Converts a `Spec` to a YAML value.
pub fn to_yaml(spec: Spec) -> Yaml {
  case spec {
    String(value:) -> yaml.String(value)
    Integer(value:) -> yaml.Int(value)
    Float(value:) -> yaml.Float(value)
    Boolean(value:) -> yaml.Bool(value)
    Null -> yaml.Null
    Array(values:) -> yaml.Sequence(list.map(values, to_yaml))
    Object(properties:) ->
      yaml.Mapping(list.map(properties, pair.map_second(_, to_yaml)))
  }
}
