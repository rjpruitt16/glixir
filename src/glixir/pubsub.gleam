////
//// This module provides a *phantom-typed* interface to Phoenix PubSub.
//// All PubSub systems are parameterized by their `message_type`,
//// and use JSON serialization for type-safe cross-process communication.
////
//// IMPORTANT: PubSub names must be pre-existing atoms to prevent atom table overflow.
//// Users are responsible for creating atoms safely before calling start().

// Type-safe, phantom-typed PubSub for Gleam/Elixir interop

import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/erlang/atom.{type Atom}
import gleam/erlang/process.{type Pid}
import gleam/json
import gleam/string
import glixir/utils
import logging

/// Opaque phantom-typed PubSub system
pub opaque type PubSub(message_type) {
  PubSub(pid: Pid)
}

/// Errors from PubSub operations
pub type PubSubError {
  StartError(String)
  SubscribeError(String)
  BroadcastError(String)
  UnsubscribeError(String)
  EncodeError(String)
  DecodeError(String)
}

// Message encoder/decoder types for type safety
pub type MessageEncoder(message_type) =
  fn(message_type) -> String

pub type MessageDecoder(message_type) =
  fn(String) -> Result(message_type, String)

// FFI Result types for pattern matching
pub type PubSubStartResult {
  PubsubStartOk(pid: Pid)
  PubsubStartError(reason: Dynamic)
}

pub type PubSubSubscribeResult {
  PubsubSubscribeOk
  PubsubSubscribeError(reason: Dynamic)
}

pub type PubSubBroadcastResult {
  PubsubBroadcastOk
  PubsubBroadcastError(reason: Dynamic)
}

pub type PubSubUnsubscribeResult {
  PubsubUnsubscribeOk
  PubsubUnsubscribeError(reason: Dynamic)
}

// ============ FFI BINDINGS ==============
@external(erlang, "Elixir.Glixir.PubSub", "start")
fn start_ffi(name: Atom) -> PubSubStartResult

@external(erlang, "Elixir.Glixir.PubSub", "subscribe")
fn subscribe_ffi(
  pubsub_name: Atom,
  topic: String,
  gleam_module: String,
  gleam_function: String,
) -> PubSubSubscribeResult

@external(erlang, "Elixir.Glixir.PubSub", "broadcast")
fn broadcast_ffi(
  pubsub_name: Atom,
  topic: String,
  json_message: String,
) -> PubSubBroadcastResult

@external(erlang, "Elixir.Glixir.PubSub", "unsubscribe")
fn unsubscribe_ffi(pubsub_name: Atom, topic: String) -> PubSubUnsubscribeResult

// ============ PUBLIC API ==============

/// Start a phantom-typed PubSub system with bounded message types
/// 
/// IMPORTANT: The atom must already exist to prevent atom table overflow.
/// Use atom.create_from_string() or atom.from_string() safely before calling this.
pub fn start(name: Atom) -> Result(PubSub(message_type), PubSubError) {
  utils.debug_log_with_prefix(
    logging.Debug,
    "pubsub",
    "Starting PubSub: " <> atom.to_string(name),
  )

  case start_ffi(name) {
    PubsubStartOk(pid) -> {
      utils.debug_log_with_prefix(
        logging.Info,
        "pubsub",
        "PubSub started successfully",
      )
      Ok(PubSub(pid))
    }
    PubsubStartError(reason) -> {
      utils.debug_log_with_prefix(
        logging.Error,
        "pubsub",
        "PubSub start failed",
      )
      Error(StartError(string.inspect(reason)))
    }
  }
}

/// Subscribe to a topic with message handling
/// The gleam_function must accept a single String parameter (JSON) and return Nil
pub fn subscribe(
  pubsub_name: Atom,
  topic: String,
  gleam_module: String,
  gleam_function: String,
) -> Result(Nil, PubSubError) {
  utils.debug_log_with_prefix(
    logging.Debug,
    "pubsub",
    "Subscribing to topic: " <> topic,
  )

  case subscribe_ffi(pubsub_name, topic, gleam_module, gleam_function) {
    PubsubSubscribeOk -> {
      utils.debug_log_with_prefix(
        logging.Info,
        "pubsub",
        "Subscribed successfully to: " <> topic,
      )
      Ok(Nil)
    }
    PubsubSubscribeError(reason) -> {
      utils.debug_log_with_prefix(
        logging.Error,
        "pubsub",
        "Subscribe failed for topic: " <> topic,
      )
      Error(SubscribeError(string.inspect(reason)))
    }
  }
}

/// Broadcast a message to all subscribers using JSON serialization
pub fn broadcast(
  pubsub_name: Atom,
  topic: String,
  message: message_type,
  encode: MessageEncoder(message_type),
) -> Result(Nil, PubSubError) {
  utils.debug_log_with_prefix(
    logging.Debug,
    "pubsub",
    "Broadcasting to topic: " <> topic,
  )

  // Encode the message to JSON
  let json_message = encode(message)

  case broadcast_ffi(pubsub_name, topic, json_message) {
    PubsubBroadcastOk -> {
      utils.debug_log_with_prefix(
        logging.Info,
        "pubsub",
        "Broadcast successful to: " <> topic,
      )
      Ok(Nil)
    }
    PubsubBroadcastError(reason) -> {
      utils.debug_log_with_prefix(
        logging.Error,
        "pubsub",
        "Broadcast failed for topic: " <> topic,
      )
      Error(BroadcastError(string.inspect(reason)))
    }
  }
}

/// Unsubscribe from a topic
pub fn unsubscribe(pubsub_name: Atom, topic: String) -> Result(Nil, PubSubError) {
  utils.debug_log_with_prefix(
    logging.Debug,
    "pubsub",
    "Unsubscribing from topic: " <> topic,
  )

  case unsubscribe_ffi(pubsub_name, topic) {
    PubsubUnsubscribeOk -> {
      utils.debug_log_with_prefix(
        logging.Info,
        "pubsub",
        "Unsubscribed successfully from: " <> topic,
      )
      Ok(Nil)
    }
    PubsubUnsubscribeError(reason) -> {
      utils.debug_log_with_prefix(
        logging.Error,
        "pubsub",
        "Unsubscribe failed for topic: " <> topic,
      )
      Error(UnsubscribeError(string.inspect(reason)))
    }
  }
}

// ============ CONVENIENCE ENCODERS/DECODERS ==============

/// JSON encoder for String messages
pub fn string_encoder(message: String) -> String {
  json.string(message) |> json.to_string
}

/// JSON decoder for String messages  
pub fn string_decoder(json_string: String) -> Result(String, String) {
  case json.parse(json_string, decode.string) {
    Ok(message) -> Ok(message)
    Error(_) -> Error("Failed to decode string from JSON")
  }
}

/// JSON encoder for Int messages
pub fn int_encoder(message: Int) -> String {
  json.int(message) |> json.to_string
}

/// JSON decoder for Int messages
pub fn int_decoder(json_string: String) -> Result(Int, String) {
  case json.parse(json_string, decode.int) {
    Ok(message) -> Ok(message)
    Error(_) -> Error("Failed to decode int from JSON")
  }
}
