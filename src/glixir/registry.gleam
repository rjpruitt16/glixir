//// Registry support for Subject lookup with dynamic spawning
//// 
//// This module provides a Gleam-friendly interface to Elixir's Registry,
//// using our Elixir helper module for clean data conversion.

import gleam/dynamic.{type Dynamic}
import gleam/erlang/process.{type Pid, type Subject}
import gleam/string
import logging

/// Opaque type representing a registry process
pub opaque type Registry {
  Registry(pid: Pid)
}

/// Registry configuration options
pub type RegistryKeys {
  Unique
  Duplicate
}

/// Errors from registry operations
pub type RegistryError {
  StartError(reason: String)
  RegisterError(reason: String)
  LookupError(reason: String)
  UnregisterError(reason: String)
  AlreadyExists
  NotFound
}

// ============================================================================
// RESULT TYPES - These match the Elixir helper return tuples
// ============================================================================

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

// ============================================================================
// FFI FUNCTIONS - Using Elixir Helper Module
// ============================================================================

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

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

// Helper to convert registry keys enum to string
fn keys_to_string(keys: RegistryKeys) -> String {
  case keys {
    Unique -> "unique"
    Duplicate -> "duplicate"
  }
}

// ============================================================================
// REGISTRY PUBLIC FUNCTIONS
// ============================================================================

/// Start a new Registry with the given name and key type
pub fn start_registry(
  name: String,
  keys: RegistryKeys,
) -> Result(Registry, RegistryError) {
  case start_registry_ffi(name, keys_to_string(keys)) {
    RegistryStartOk(pid) -> Ok(Registry(pid))
    RegistryStartError(reason) -> Error(StartError(string.inspect(reason)))
  }
}

/// Start a unique key registry (most common use case)
pub fn start_unique_registry(name: String) -> Result(Registry, RegistryError) {
  start_registry(name, Unique)
}

/// Register a Subject with a key in the registry
pub fn register_subject(
  registry_name: String,
  key: String,
  subject: Subject(message),
) -> Result(Nil, RegistryError) {
  case register_subject_ffi(registry_name, key, subject) {
    RegistryRegisterOk -> Ok(Nil)
    RegistryRegisterError(reason) ->
      Error(RegisterError(string.inspect(reason)))
  }
}

/// Look up a Subject by key in the registry
pub fn lookup_subject(
  registry_name: String,
  key: String,
) -> Result(Subject(message), RegistryError) {
  case lookup_subject_ffi(registry_name, key) {
    RegistryLookupOk(subject) -> Ok(subject)
    RegistryLookupNotFound -> Error(NotFound)
    RegistryLookupError(reason) -> Error(LookupError(string.inspect(reason)))
  }
}

/// Unregister a key from the registry
pub fn unregister_subject(
  registry_name: String,
  key: String,
) -> Result(Nil, RegistryError) {
  case unregister_subject_ffi(registry_name, key) {
    RegistryUnregisterOk -> Ok(Nil)
    RegistryUnregisterError(reason) ->
      Error(UnregisterError(string.inspect(reason)))
  }
}

// ============================================================================
// CONVENIENCE FUNCTIONS FOR COMMON PATTERNS
// ============================================================================

/// Register a subject with a custom key
pub fn register_with_key(
  registry_name: String,
  key: String,
  subject: Subject(message),
) -> Result(Nil, RegistryError) {
  register_subject(registry_name, key, subject)
}

/// Look up a subject by custom key
pub fn lookup_with_key(
  registry_name: String,
  key: String,
) -> Result(Subject(message), RegistryError) {
  lookup_subject(registry_name, key)
}

/// Unregister a subject by custom key
pub fn unregister_with_key(
  registry_name: String,
  key: String,
) -> Result(Nil, RegistryError) {
  unregister_subject(registry_name, key)
}
