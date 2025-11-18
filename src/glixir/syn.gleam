////
//// Distributed process coordination using Erlang's `syn` library.
//// 
//// Provides type-safe wrappers for syn's registry and PubSub functionality,
//// enabling distributed service discovery and event streaming across BEAM nodes.
////
//// Inspired by the excellent glyn project's syn wrapper patterns.
//// Check out glyn for more advanced OTP patterns: https://github.com/glyn-project/glyn
////
//// This implementation is optimized for glixir's type-safe OTP wrappers.
////

import gleam/dynamic.{type Dynamic}
import gleam/erlang/atom.{type Atom}
import gleam/erlang/process.{type Pid}
import gleam/json
import gleam/list
import gleam/string
import glixir/utils
import logging

// ============================================================================
// TYPES
// ============================================================================

/// syn operation result (internal)
type SynResult

/// syn success marker (internal)  
type SynOk

/// Registry operation errors
pub type RegistryError {
  RegistrationFailed(String)
  LookupFailed(String)
  UnregistrationFailed(String)
}

/// PubSub operation errors
pub type PubSubError {
  JoinFailed(String)
  LeaveFailed(String)
  PublishFailed(String)
}

// Define result types for pattern matching
pub type WhereisResult {
  NotFound
  FoundPidOnly(Pid)
  FoundWithMetadata(Pid, Dynamic)
  WhereisError(String)
}

pub type SynWhereisResult {
  SynNotFound
  SynFoundPidOnly(Pid)
  SynFoundWithMetadata(Pid, Dynamic)
  SynError(Dynamic)
}

pub type SynRegisterResult {
  SynRegisterOk
  SynRegisterError(Dynamic)
}

// Add these result types
pub type SynUnregisterResult {
  SynUnregisterOk
  SynUnregisterError(Dynamic)
}

pub type SynLookupResult {
  SynLookupNotFound
  SynLookupFound(Pid, Dynamic)
  SynLookupError(Dynamic)
}

pub type SynMembersResult {
  SynMembersEmpty
  SynMembersList(List(#(String, Pid, Dynamic)))
  SynMembersError(Dynamic)
}

pub type SynIsMemberResult {
  SynIsMemberTrue
  SynIsMemberFalse
  SynIsMemberError(Dynamic)
}

// ============================================================================
// FFI BINDINGS
// ============================================================================

// Scope management
@external(erlang, "syn", "add_node_to_scopes")
fn syn_add_node_to_scopes(scopes: List(Atom)) -> SynOk

// Update FFI declarations to use these types
@external(erlang, "glixir_syn", "whereis_name")
fn syn_whereis_bridge(scope: String, name: String) -> SynWhereisResult

@external(erlang, "glixir_syn", "register")
fn syn_register_bridge(
  scope: String,
  name: String,
  pid: Pid,
  metadata: Dynamic,
) -> SynRegisterResult

// Add FFI bindings
@external(erlang, "glixir_syn", "unregister")
fn syn_unregister_bridge(scope: String, name: String) -> SynUnregisterResult

@external(erlang, "glixir_syn", "lookup")
fn syn_lookup_bridge(scope: String, name: String) -> SynLookupResult

@external(erlang, "glixir_syn", "members")
fn syn_members_bridge(scope: String, group: String) -> SynMembersResult

@external(erlang, "glixir_syn", "is_member")
fn syn_is_member_bridge(
  scope: String,
  name: String,
  pid: Pid,
) -> SynIsMemberResult

// PubSub operations
@external(erlang, "syn", "join")
fn syn_join(scope: Atom, group: String, pid: Pid) -> SynResult

@external(erlang, "syn", "leave")
fn syn_leave(scope: Atom, group: String, pid: Pid) -> SynResult

@external(erlang, "syn", "publish")
fn syn_publish(
  scope: Atom,
  group: String,
  message: Dynamic,
) -> Result(Int, Dynamic)

@external(erlang, "syn", "member_count")
fn syn_member_count(scope: Atom, group: String) -> Int

// Utility FFI
@external(erlang, "gleam_stdlib", "identity")
fn to_dynamic(value: a) -> Dynamic

@external(erlang, "gleam_stdlib", "identity")
fn from_dynamic(value: Dynamic) -> a

// Convert syn results to Gleam results
fn syn_result_to_gleam(result: SynResult) -> Result(Nil, Dynamic) {
  // syn returns 'ok' atom on success, {error, Reason} on failure
  case to_dynamic(result) == to_dynamic(atom.create("ok")) {
    True -> Ok(Nil)
    False -> {
      // Extract error reason from {error, Reason} tuple
      let #(_error_atom, reason) = from_dynamic(to_dynamic(result))
      Error(reason)
    }
  }
}

// ============================================================================
// SCOPE MANAGEMENT
// ============================================================================

/// Initialize scopes for distributed coordination.
/// Call this once at application startup for each scope you plan to use.
/// 
/// ## Example
/// ```gleam
/// syn.init_scopes(["user_sessions", "game_lobbies", "worker_pool"])
/// ```
pub fn init_scopes(scopes: List(String)) -> Nil {
  let scope_atoms = list.map(scopes, atom.create)

  utils.debug_log_with_prefix(
    logging.Info,
    "syn",
    "Initializing scopes: " <> string.inspect(scopes),
  )

  syn_add_node_to_scopes(scope_atoms)
  Nil
}

// ============================================================================
// REGISTRY API
// ============================================================================

/// Register the current process in a scope with metadata.
/// The process can be looked up later by other nodes using the scope and name.
/// 
/// ## Example
/// ```gleam
/// // Register a user session
/// syn.register("user_sessions", user_id, #(username, last_active))
/// ```
// Update your whereis function to use the bridge
// And register becomes:
pub fn register(
  scope: String,
  name: String,
  metadata: metadata,
) -> Result(Nil, RegistryError) {
  let current_pid = process.self()

  utils.debug_log_with_prefix(
    logging.Debug,
    "syn",
    "Registering process: " <> scope <> "/" <> name,
  )

  case syn_register_bridge(scope, name, current_pid, to_dynamic(metadata)) {
    SynRegisterOk -> {
      utils.debug_log_with_prefix(
        logging.Info,
        "syn",
        "Registered successfully: " <> name,
      )
      Ok(Nil)
    }

    SynRegisterError(reason) -> {
      let error_msg = "Registration failed: " <> string.inspect(reason)
      utils.debug_log_with_prefix(logging.Error, "syn", error_msg)
      Error(RegistrationFailed(error_msg))
    }
  }
}

/// Look up a registered process by scope and name.
/// Returns the process PID and its metadata if found.
/// 
/// ## Example  
/// ```gleam
/// case syn.whereis("user_sessions", user_id) {
///   Ok(#(pid, #(username, last_active))) -> // Send message to user
///   Error(_) -> // User not online
/// }
/// ```
pub fn whereis(
  scope: String,
  name: String,
) -> Result(#(Pid, metadata), RegistryError) {
  utils.debug_log_with_prefix(
    logging.Debug,
    "syn",
    "Looking up process: " <> scope <> "/" <> name,
  )

  case syn_whereis_bridge(scope, name) {
    SynNotFound -> {
      let error_msg = "Process not found: " <> scope <> "/" <> name
      utils.debug_log_with_prefix(logging.Debug, "syn", error_msg)
      Error(LookupFailed(error_msg))
    }

    SynFoundPidOnly(_pid) -> {
      let error_msg =
        "Process found but has no metadata: " <> scope <> "/" <> name
      utils.debug_log_with_prefix(logging.Warning, "syn", error_msg)
      Error(LookupFailed(error_msg))
    }

    SynFoundWithMetadata(pid, metadata_dyn) -> {
      let metadata = from_dynamic(metadata_dyn)
      utils.debug_log_with_prefix(
        logging.Debug,
        "syn",
        "Found process with metadata: " <> scope <> "/" <> name,
      )
      Ok(#(pid, metadata))
    }

    SynError(reason) -> {
      let error_msg = "Syn error: " <> string.inspect(reason)
      utils.debug_log_with_prefix(logging.Error, "syn", error_msg)
      Error(LookupFailed(error_msg))
    }
  }
}

/// Unregister a process by scope and name.
/// The process will no longer be discoverable by other nodes.
/// 
/// ## Example
/// ```gleam
/// syn.unregister("user_sessions", user_id)
/// ```
// Update unregister to use the bridge

pub fn unregister(scope: String, name: String) -> Result(Nil, RegistryError) {
  utils.debug_log_with_prefix(
    logging.Debug,
    "syn",
    "Unregistering process: " <> scope <> "/" <> name,
  )

  case syn_unregister_bridge(scope, name) {
    SynUnregisterOk -> {
      utils.debug_log_with_prefix(
        logging.Info,
        "syn",
        "Unregistered successfully: " <> name,
      )
      Ok(Nil)
    }

    SynUnregisterError(reason) -> {
      let error_msg = "Unregistration failed: " <> string.inspect(reason)
      utils.debug_log_with_prefix(logging.Error, "syn", error_msg)
      Error(UnregistrationFailed(error_msg))
    }
  }
}

// ============================================================================
// PUBSUB API  
// ============================================================================

/// Join a PubSub group to receive published messages.
/// The current process will receive all messages published to this group.
/// 
/// ## Example
/// ```gleam
/// syn.join("chat_rooms", "general")
/// // Process will now receive all messages published to "general" chat
/// ```
pub fn join(scope: String, group: String) -> Result(Nil, PubSubError) {
  let scope_atom = atom.create(scope)
  let current_pid = process.self()

  utils.debug_log_with_prefix(
    logging.Debug,
    "syn",
    "Joining PubSub group: " <> scope <> "/" <> group,
  )

  case syn_join(scope_atom, group, current_pid) {
    result ->
      case syn_result_to_gleam(result) {
        Ok(Nil) -> {
          utils.debug_log_with_prefix(
            logging.Info,
            "syn",
            "Joined group successfully: " <> group,
          )
          Ok(Nil)
        }
        Error(reason) -> {
          let error_msg = "Join failed: " <> string.inspect(reason)
          utils.debug_log_with_prefix(logging.Error, "syn", error_msg)
          Error(JoinFailed(error_msg))
        }
      }
  }
}

/// Leave a PubSub group to stop receiving messages.
/// The current process will no longer receive messages published to this group.
/// 
/// ## Example
/// ```gleam
/// syn.leave("chat_rooms", "general")
/// ```
pub fn leave(scope: String, group: String) -> Result(Nil, PubSubError) {
  let scope_atom = atom.create(scope)
  let current_pid = process.self()

  utils.debug_log_with_prefix(
    logging.Debug,
    "syn",
    "Leaving PubSub group: " <> scope <> "/" <> group,
  )

  case syn_leave(scope_atom, group, current_pid) {
    result ->
      case syn_result_to_gleam(result) {
        Ok(Nil) -> {
          utils.debug_log_with_prefix(
            logging.Info,
            "syn",
            "Left group successfully: " <> group,
          )
          Ok(Nil)
        }
        Error(reason) -> {
          let error_msg = "Leave failed: " <> string.inspect(reason)
          utils.debug_log_with_prefix(logging.Error, "syn", error_msg)
          Error(LeaveFailed(error_msg))
        }
      }
  }
}

/// Publish a string message to all members of a PubSub group.
/// Returns the number of processes the message was delivered to.
/// 
/// ## Example
/// ```gleam
/// case syn.publish("chat_rooms", "general", "Hello everyone!") {
///   Ok(count) -> // Message sent to `count` processes
///   Error(_) -> // Publish failed
/// }
/// ```
pub fn publish(
  scope: String,
  group: String,
  message: String,
) -> Result(Int, PubSubError) {
  let scope_atom = atom.create(scope)

  utils.debug_log_with_prefix(
    logging.Debug,
    "syn",
    "Publishing to group: " <> scope <> "/" <> group,
  )

  case syn_publish(scope_atom, group, to_dynamic(message)) {
    Ok(count) -> {
      utils.debug_log_with_prefix(
        logging.Info,
        "syn",
        "Published to " <> string.inspect(count) <> " processes",
      )
      Ok(count)
    }
    Error(reason) -> {
      let error_msg = "Publish failed: " <> string.inspect(reason)
      utils.debug_log_with_prefix(logging.Error, "syn", error_msg)
      Error(PublishFailed(error_msg))
    }
  }
}

/// Publish a typed message using JSON encoding.
/// The message will be JSON-encoded before sending to subscribers.
/// 
/// ## Example
/// ```gleam
/// let user_message = json.object([
///   #("user", json.string("alice")),
///   #("content", json.string("Hello!")),
///   #("timestamp", json.int(system_time))
/// ])
/// 
/// syn.publish_json("chat_rooms", "general", user_message, fn(j) { j })
/// ```
pub fn publish_json(
  scope: String,
  group: String,
  message: message,
  encoder: fn(message) -> json.Json,
) -> Result(Int, PubSubError) {
  let json_string =
    encoder(message)
    |> json.to_string

  publish(scope, group, json_string)
}

/// Get list of all process PIDs subscribed to a group.
/// Useful for debugging or monitoring subscriber counts.
/// 
/// ## Example
/// ```gleam
/// let active_users = syn.members("user_sessions", "online")
/// io.println("Active users: " <> string.inspect(list.length(active_users)))
/// ```
// Update unregister to use the bridge
// Add lookup function (alternative to whereis that uses syn:lookup)
pub fn lookup(
  scope: String,
  name: String,
) -> Result(#(Pid, metadata), RegistryError) {
  utils.debug_log_with_prefix(
    logging.Debug,
    "syn",
    "Looking up (via lookup): " <> scope <> "/" <> name,
  )

  case syn_lookup_bridge(scope, name) {
    SynLookupNotFound -> {
      Error(LookupFailed("Process not found: " <> scope <> "/" <> name))
    }

    SynLookupFound(pid, metadata_dyn) -> {
      let metadata = from_dynamic(metadata_dyn)
      Ok(#(pid, metadata))
    }

    SynLookupError(reason) -> {
      Error(LookupFailed("Lookup error: " <> string.inspect(reason)))
    }
  }
}

// Add function to get detailed member list
pub fn members_detailed(
  scope: String,
  group: String,
) -> List(#(String, Pid, metadata)) {
  case syn_members_bridge(scope, group) {
    SynMembersEmpty -> []

    SynMembersList(members) -> {
      list.map(members, fn(member) {
        let #(name, pid, meta_dyn) = member
        #(name, pid, from_dynamic(meta_dyn))
      })
    }

    SynMembersError(_) -> []
  }
}

/// Get list of member PIDs and metadata without names.
/// Simpler version of members_detailed for when you don't need member names.
///
/// ## Example
/// ```gleam
/// let followers = syn.members("JobDispatcherFollowers", "dispatchers")
/// // Returns: [#(pid1, metadata1), #(pid2, metadata2)]
/// ```
pub fn members(scope: String, group: String) -> List(#(Pid, metadata)) {
  case syn_members_bridge(scope, group) {
    SynMembersEmpty -> []

    SynMembersList(members) -> {
      list.map(members, fn(member) {
        let #(_name, pid, meta_dyn) = member
        #(pid, from_dynamic(meta_dyn))
      })
    }

    SynMembersError(_) -> []
  }
}

// Add is_member check
pub fn is_member(scope: String, name: String, pid: Pid) -> Bool {
  case syn_is_member_bridge(scope, name, pid) {
    SynIsMemberTrue -> True
    SynIsMemberFalse -> False
    SynIsMemberError(_) -> False
  }
}

/// Get count of processes subscribed to a group.
/// More efficient than getting the full member list if you only need the count.
/// 
/// ## Example
/// ```gleam
/// let user_count = syn.member_count("chat_rooms", "general")
/// if user_count > 100 {
///   // Maybe split the room
/// }
/// ```
pub fn member_count(scope: String, group: String) -> Int {
  let scope_atom = atom.create(scope)
  syn_member_count(scope_atom, group)
}

// ============================================================================
// CONVENIENCE PATTERNS
// ============================================================================

/// Register a worker process with load information.
/// Common pattern for distributed worker pools.
/// 
/// ## Example
/// ```gleam
/// syn.register_worker("image_processors", worker_id, #(cpu_usage, queue_size))
/// ```
pub fn register_worker(
  pool_name: String,
  worker_id: String,
  load_info: load_info,
) -> Result(Nil, RegistryError) {
  register("worker_pools", pool_name <> "/" <> worker_id, load_info)
}

/// Find a worker in a pool and get its load information.
/// 
/// ## Example
/// ```gleam
/// case syn.find_worker("image_processors", worker_id) {
///   Ok(#(pid, #(cpu_usage, queue_size))) -> // Send work to worker
///   Error(_) -> // Worker not available
/// }
/// ```
pub fn find_worker(
  pool_name: String,
  worker_id: String,
) -> Result(#(Pid, load_info), RegistryError) {
  whereis("worker_pools", pool_name <> "/" <> worker_id)
}

/// Broadcast a status update to all processes in a coordination group.
/// Common pattern for distributed consensus or health monitoring.
/// 
/// ## Example
/// ```gleam
/// let status = json.object([
///   #("node", json.string(node_name)),
///   #("load", json.float(cpu_load)),
///   #("timestamp", json.int(now))
/// ])
/// 
/// syn.broadcast_status("health_check", status)
/// ```
pub fn broadcast_status(
  group: String,
  status_message: json.Json,
) -> Result(Int, PubSubError) {
  publish_json("coordination", group, status_message, fn(j) { j })
}

/// Join a coordination group for distributed algorithm participation.
/// Common pattern for consensus, leader election, or load balancing.
/// 
/// ## Example
/// ```gleam
/// syn.join_coordination("leader_election")
/// // Process will receive leader election messages
/// ```
pub fn join_coordination(group: String) -> Result(Nil, PubSubError) {
  join("coordination", group)
}

/// Leave a coordination group.
/// 
/// ## Example
/// ```gleam
/// syn.leave_coordination("leader_election") 
/// ```
pub fn leave_coordination(group: String) -> Result(Nil, PubSubError) {
  leave("coordination", group)
}
