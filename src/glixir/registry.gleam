//// Type-safe, phantom-typed Registry for Gleam/Elixir interop
////
//// This module provides a *phantom-typed* interface to Elixir Registry.
//// All registries are parameterized by their `key_type` and `message_type`,
//// so misuse is a compile error, not a runtime surprise.

import gleam/dynamic.{type Dynamic}
import gleam/erlang/atom.{type Atom}
import gleam/erlang/process.{type Pid, type Subject}
import gleam/int
import gleam/string
import logging
import utils

/// Opaque phantom-typed registry
pub opaque type Registry(key_type, message_type) {
  Registry(pid: Pid)
}

/// Registry configuration options
pub type RegistryKeys {
  Unique
  Duplicate
}

/// Errors from registry operations
pub type RegistryError {
  StartError(String)
  RegisterError(String)
  LookupError(String)
  UnregisterError(String)
  AlreadyExists
  NotFound
}

// FFI Result types for pattern matching
pub type RegistryStartResult {
  RegistryStartOk(pid: Pid)
  RegistryStartError(reason: Dynamic)
}

pub type RegistryRegisterResult {
  RegistryRegisterOk
  RegistryRegisterError(reason: Dynamic)
}

pub type RegistryLookupResult(message) {
  RegistryLookupOk(subject: Subject(message))
  RegistryLookupNotFound
  RegistryLookupError(reason: Dynamic)
}

pub type RegistryUnregisterResult {
  RegistryUnregisterOk
  RegistryUnregisterError(reason: Dynamic)
}

// ============ FFI BINDINGS ==============
@external(erlang, "Elixir.Glixir.Registry", "start_registry")
fn start_registry_ffi(name: String, keys: String) -> RegistryStartResult

@external(erlang, "Elixir.Glixir.Registry", "register_subject")
fn register_subject_ffi(
  registry_name: String,
  key: String,
  subject: Subject(message),
) -> RegistryRegisterResult

@external(erlang, "Elixir.Glixir.Registry", "lookup_subject")
fn lookup_subject_ffi(
  registry_name: String,
  key: String,
) -> RegistryLookupResult(message)

@external(erlang, "Elixir.Glixir.Registry", "unregister_subject")
fn unregister_subject_ffi(
  registry_name: String,
  key: String,
) -> RegistryUnregisterResult

// ============ HELPERS ==============
fn keys_to_string(keys: RegistryKeys) -> String {
  case keys {
    Unique -> "unique"
    Duplicate -> "duplicate"
  }
}

// Key encoder - users must provide this for their key type
pub type KeyEncoder(key_type) =
  fn(key_type) -> String

// ============ PUBLIC API ==============

/// Start a phantom-typed registry with bounded key and message types
pub fn start_registry(
  name: Atom,
  keys: RegistryKeys,
) -> Result(Registry(key_type, message_type), RegistryError) {
  utils.debug_log_with_prefix(
    logging.Debug,
    "registry",
    "Starting registry: " <> atom.to_string(name),
  )

  case start_registry_ffi(atom.to_string(name), keys_to_string(keys)) {
    RegistryStartOk(pid) -> {
      utils.debug_log_with_prefix(
        logging.Info,
        "registry",
        "Registry started successfully",
      )
      Ok(Registry(pid))
    }
    RegistryStartError(reason) -> {
      utils.debug_log_with_prefix(
        logging.Error,
        "registry",
        "Registry start failed",
      )
      Error(StartError(string.inspect(reason)))
    }
  }
}

/// Start a unique key registry (most common use case)
pub fn start_unique_registry(
  name: Atom,
) -> Result(Registry(key_type, message_type), RegistryError) {
  start_registry(name, Unique)
}

/// Register a Subject with a typed key in the phantom-typed registry
pub fn register_subject(
  registry_name: Atom,
  key: key_type,
  subject: Subject(message_type),
  encode_key: KeyEncoder(key_type),
) -> Result(Nil, RegistryError) {
  utils.debug_log_with_prefix(
    logging.Debug,
    "registry",
    "Registering subject with key",
  )

  case
    register_subject_ffi(
      atom.to_string(registry_name),
      encode_key(key),
      subject,
    )
  {
    RegistryRegisterOk -> {
      utils.debug_log_with_prefix(
        logging.Info,
        "registry",
        "Subject registered successfully",
      )
      Ok(Nil)
    }
    RegistryRegisterError(reason) -> {
      utils.debug_log_with_prefix(
        logging.Error,
        "registry",
        "Subject registration failed",
      )
      Error(RegisterError(string.inspect(reason)))
    }
  }
}

/// Look up a Subject by typed key in the phantom-typed registry
pub fn lookup_subject(
  registry_name: Atom,
  key: key_type,
  encode_key: KeyEncoder(key_type),
) -> Result(Subject(message_type), RegistryError) {
  utils.debug_log_with_prefix(
    logging.Debug,
    "registry",
    "Looking up subject by key",
  )

  case lookup_subject_ffi(atom.to_string(registry_name), encode_key(key)) {
    RegistryLookupOk(subject) -> {
      utils.debug_log_with_prefix(
        logging.Info,
        "registry",
        "Subject found successfully",
      )
      Ok(subject)
    }
    RegistryLookupNotFound -> {
      utils.debug_log_with_prefix(
        logging.Warning,
        "registry",
        "Subject not found",
      )
      Error(NotFound)
    }
    RegistryLookupError(reason) -> {
      utils.debug_log_with_prefix(
        logging.Error,
        "registry",
        "Subject lookup failed",
      )
      Error(LookupError(string.inspect(reason)))
    }
  }
}

/// Unregister a key from the phantom-typed registry
pub fn unregister_subject(
  registry_name: Atom,
  key: key_type,
  encode_key: KeyEncoder(key_type),
) -> Result(Nil, RegistryError) {
  utils.debug_log_with_prefix(
    logging.Debug,
    "registry",
    "Unregistering subject",
  )

  case unregister_subject_ffi(atom.to_string(registry_name), encode_key(key)) {
    RegistryUnregisterOk -> {
      utils.debug_log_with_prefix(
        logging.Info,
        "registry",
        "Subject unregistered successfully",
      )
      Ok(Nil)
    }
    RegistryUnregisterError(reason) -> {
      utils.debug_log_with_prefix(
        logging.Error,
        "registry",
        "Subject unregistration failed",
      )
      Error(UnregisterError(string.inspect(reason)))
    }
  }
}

// ============ CONVENIENCE ENCODERS ==============

/// Encoder for Atom keys (most common case)
pub fn atom_key_encoder(key: Atom) -> String {
  atom.to_string(key)
}

/// Encoder for String keys
pub fn string_key_encoder(key: String) -> String {
  key
}

/// Encoder for Int keys
pub fn int_key_encoder(key: Int) -> String {
  int.to_string(key)
}

/// Encoder for user ID keys (common pattern)
pub fn user_id_encoder(user_id: Int) -> String {
  "user_" <> int.to_string(user_id)
}

/// Encoder for session keys (common pattern)  
pub fn session_key_encoder(session_id: String) -> String {
  "session_" <> session_id
}
