////
//// Syn PubSub bridge for Gleam actors.
////
//// Similar to glixir/pubsub but uses :syn instead of Phoenix.PubSub.
//// Messages are passed as strings (typically JSON) for type-safe interop.
////

import gleam/dynamic.{type Dynamic}
import gleam/string
import glixir/utils
import logging

/// Errors from syn pubsub operations
pub type SynPubSubError {
  SubscribeError(String)
  PublishError(String)
}

// FFI Result types for pattern matching
pub type SynPubSubSubscribeResult {
  SynPubsubSubscribeOk
  SynPubsubSubscribeError(reason: Dynamic)
}

pub type SynPubSubPublishResult {
  SynPubsubPublishOk(count: Int)
  SynPubsubPublishError(reason: Dynamic)
}

// ============ FFI BINDINGS ==============
@external(erlang, "Elixir.Glixir.SynPubSub", "subscribe")
fn subscribe_ffi(
  scope: String,
  group: String,
  gleam_module: String,
  gleam_function: String,
) -> SynPubSubSubscribeResult

@external(erlang, "Elixir.Glixir.SynPubSub", "subscribe")
fn subscribe_with_key_ffi(
  scope: String,
  group: String,
  gleam_module: String,
  gleam_function: String,
  registry_key: String,
) -> SynPubSubSubscribeResult

@external(erlang, "Elixir.Glixir.SynPubSub", "publish")
fn publish_ffi(
  scope: String,
  group: String,
  message: String,
) -> SynPubSubPublishResult

// ============ PUBLIC API ==============

/// Subscribe to a syn pubsub group with message handling
/// The gleam_function must accept a single String parameter (typically JSON) and return Nil
///
/// ## Example
/// ```gleam
/// syn_pubsub.subscribe(
///   "job_completions",
///   "all",
///   "actors@url_queue_actor",
///   "handle_job_cancellation"
/// )
/// ```
pub fn subscribe(
  scope: String,
  group: String,
  gleam_module: String,
  gleam_function: String,
) -> Result(Nil, SynPubSubError) {
  utils.debug_log_with_prefix(
    logging.Debug,
    "syn_pubsub",
    "Subscribing to " <> scope <> "/" <> group,
  )

  case subscribe_ffi(scope, group, gleam_module, gleam_function) {
    SynPubsubSubscribeOk -> {
      utils.debug_log_with_prefix(
        logging.Info,
        "syn_pubsub",
        "Subscribed successfully to: " <> scope <> "/" <> group,
      )
      Ok(Nil)
    }
    SynPubsubSubscribeError(reason) -> {
      utils.debug_log_with_prefix(
        logging.Error,
        "syn_pubsub",
        "Subscribe failed for " <> scope <> "/" <> group,
      )
      Error(SubscribeError(string.inspect(reason)))
    }
  }
}

/// Subscribe to a syn pubsub group with registry key for direct actor targeting
/// The gleam_function must accept two String parameters (registry_key, message) and return Nil
///
/// ## Example
/// ```gleam
/// syn_pubsub.subscribe_with_registry_key(
///   "job_completions",
///   "all",
///   "actors@url_queue_actor",
///   "handle_job_cancellation",
///   "https://api.example.com/endpoint"
/// )
/// ```
pub fn subscribe_with_registry_key(
  scope: String,
  group: String,
  gleam_module: String,
  gleam_function: String,
  registry_key: String,
) -> Result(Nil, SynPubSubError) {
  utils.debug_log_with_prefix(
    logging.Debug,
    "syn_pubsub",
    "Subscribing to "
      <> scope
      <> "/"
      <> group
      <> " with key: "
      <> registry_key,
  )

  case
    subscribe_with_key_ffi(
      scope,
      group,
      gleam_module,
      gleam_function,
      registry_key,
    )
  {
    SynPubsubSubscribeOk -> {
      utils.debug_log_with_prefix(
        logging.Info,
        "syn_pubsub",
        "Subscribed successfully to: "
          <> scope
          <> "/"
          <> group
          <> " with key: "
          <> registry_key,
      )
      Ok(Nil)
    }
    SynPubsubSubscribeError(reason) -> {
      utils.debug_log_with_prefix(
        logging.Error,
        "syn_pubsub",
        "Subscribe failed for " <> scope <> "/" <> group,
      )
      Error(SubscribeError(string.inspect(reason)))
    }
  }
}

/// Publish a message to all subscribers of a syn pubsub group
/// Returns the number of processes the message was delivered to
///
/// ## Example
/// ```gleam
/// syn_pubsub.publish("job_completions", "all", job_id)
/// |> result.map(fn(count) {
///   logging.log(Info, "Sent to " <> int.to_string(count) <> " subscribers")
/// })
/// ```
pub fn publish(
  scope: String,
  group: String,
  message: String,
) -> Result(Int, SynPubSubError) {
  utils.debug_log_with_prefix(
    logging.Debug,
    "syn_pubsub",
    "Publishing to " <> scope <> "/" <> group,
  )

  case publish_ffi(scope, group, message) {
    SynPubsubPublishOk(count) -> {
      utils.debug_log_with_prefix(
        logging.Info,
        "syn_pubsub",
        "Published to " <> string.inspect(count) <> " subscribers",
      )
      Ok(count)
    }
    SynPubsubPublishError(reason) -> {
      utils.debug_log_with_prefix(
        logging.Error,
        "syn_pubsub",
        "Publish failed for " <> scope <> "/" <> group,
      )
      Error(PublishError(string.inspect(reason)))
    }
  }
}
