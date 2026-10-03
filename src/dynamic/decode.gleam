import dynamic/serialize
import gleam/dynamic
import gleam/dynamic/decode

/// The error type returned when decoding fails.
pub type DecodeError =
  decode.DecodeError

/// A decoder for a specific type `t` that knows how to parse a dynamic value 
/// and contains the openapi specification of that type.
pub type Decoder(t) =
  serialize.Decoder(t)

/// Runs a decoder on a dynamic value, returning either the decoded 
/// value or a list of errors.
pub fn run(
  value: dynamic.Dynamic,
  decoder: Decoder(t),
) -> Result(t, List(DecodeError)) {
  decode.run(value, decoder.decoder)
}
