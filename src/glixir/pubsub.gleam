//// PubSub support for distributed messaging
//// 
//// This module provides a Gleam-friendly interface to Phoenix.PubSub,
//// using our Elixir helper module for clean data conversion.

import gleam/dynamic.{type Dynamic}
import gleam/erlang/process.{type Pid}
import gleam/string

/// Opaque type representing a PubSub system
pub opaque type PubSub {
  PubSub(pid: Pid)
}

/// Errors from PubSub operations
pub type PubSubError {
  StartError(reason: String)
  SubscribeError(reason: String)
  BroadcastError(reason: String)
  UnsubscribeError(reason: String)
}

// ============================================================================
// RESULT TYPES - These match the Elixir helper return tuples EXACTLY
// ============================================================================

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

// ============================================================================
// FFI FUNCTIONS - Using Elixir Helper Module
// ============================================================================

@external(erlang, "Elixir.Glixir.PubSub", "start_pubsub")
fn start_pubsub_ffi(name: String) -> PubSubStartResult

@external(erlang, "Elixir.Glixir.PubSub", "subscribe")
fn subscribe_ffi(pubsub_name: String, topic: String) -> PubSubSubscribeResult

@external(erlang, "Elixir.Glixir.PubSub", "broadcast")
fn broadcast_ffi(
  pubsub_name: String,
  topic: String,
  message: Dynamic,
) -> PubSubBroadcastResult

@external(erlang, "Elixir.Glixir.PubSub", "unsubscribe")
fn unsubscribe_ffi(
  pubsub_name: String,
  topic: String,
) -> PubSubUnsubscribeResult

// ============================================================================
// PUBSUB PUBLIC FUNCTIONS
// ============================================================================

/// Start a new PubSub system with the given name
pub fn start_pubsub(name: String) -> Result(PubSub, PubSubError) {
  case start_pubsub_ffi(name) {
    PubsubStartOk(pid) -> Ok(PubSub(pid))
    PubsubStartError(reason) -> Error(StartError(string.inspect(reason)))
  }
}

/// Subscribe the current process to a topic
pub fn subscribe(pubsub_name: String, topic: String) -> Result(Nil, PubSubError) {
  case subscribe_ffi(pubsub_name, topic) {
    PubsubSubscribeOk -> Ok(Nil)
    PubsubSubscribeError(reason) ->
      Error(SubscribeError(string.inspect(reason)))
  }
}

/// Broadcast a message to all subscribers of a topic
pub fn broadcast(
  pubsub_name: String,
  topic: String,
  message: a,
) -> Result(Nil, PubSubError) {
  case broadcast_ffi(pubsub_name, topic, dynamic.from(message)) {
    PubsubBroadcastOk -> Ok(Nil)
    PubsubBroadcastError(reason) ->
      Error(BroadcastError(string.inspect(reason)))
  }
}

/// Unsubscribe the current process from a topic
pub fn unsubscribe(
  pubsub_name: String,
  topic: String,
) -> Result(Nil, PubSubError) {
  case unsubscribe_ffi(pubsub_name, topic) {
    PubsubUnsubscribeOk -> Ok(Nil)
    PubsubUnsubscribeError(reason) ->
      Error(UnsubscribeError(string.inspect(reason)))
  }
}
