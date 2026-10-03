import dynamic/serialize
import dynamic/spec.{type Spec}
import gleam/json.{type Json}
import taffy/value.{type YamlValue as Yaml}

/// An encoder for a specific type 't' that knows how to convert it to a 
/// dynamic specification and contains the openapi specification of that type.
pub type Encoder(t) =
  serialize.Encoder(t)

pub fn map(encoder: Encoder(a), mapper: fn(b) -> a) -> Encoder(b) {
  serialize.Encoder(..encoder, encoder: fn(b) { encoder.encoder(mapper(b)) })
}

/// Encode a value using the given encoder.
pub fn encode(a: a, of encoder: Encoder(a)) -> Spec {
  encoder.encoder(a)
}

/// Directly encode a value using the given encoder to JSON.
pub fn encode_json(a: a, of encoder: Encoder(a)) -> Json {
  spec.to_json(encode(a, of: encoder))
}

/// Directly encode a value using the given encoder to JSON.
pub fn encode_yaml(a: a, of encoder: Encoder(a)) -> Yaml {
  spec.to_yaml(encode(a, of: encoder))
}
