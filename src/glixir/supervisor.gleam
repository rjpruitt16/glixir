//// Dynamic supervisor support for runtime process management
//// 
//// This module provides a Gleam-friendly interface to Elixir's DynamicSupervisor,
//// using our Elixir helper module for clean data conversion.

import gleam/dynamic.{type Dynamic}
import gleam/erlang/atom.{type Atom}
import gleam/erlang/process.{type Pid}
import gleam/int
import gleam/list
import gleam/string

/// Opaque type representing a supervisor process
pub opaque type Supervisor {
  Supervisor(pid: Pid)
}

pub type Started(data) {
  Started(
    /// The process identifier of the started actor. This can be used to
    /// monitor the actor, make it exit, or anything else you can do with a
    /// pid.
    pid: Pid,
    /// Data returned by the actor after it initialised. Commonly this will be
    /// a subject that it will receive messages from.
    data: data,
  )
}

/// Child restart strategy
pub type RestartStrategy {
  Permanent
  // Always restart
  Temporary
  // Never restart
  Transient
  // Restart only on abnormal termination
}

/// Supervisor strategy
pub type SupervisorStrategy {
  OneForOne
  // Restart only the failed child
  OneForAll
  // Restart all children if one fails
  RestForOne
  // Restart failed child and any started after it
}

pub type ChildType {
  Worker
  SupervisorChild
}

/// Errors from supervisor operations
pub type SupervisorError {
  StartError(reason: String)
  ChildStartError(id: String, reason: String)
  ChildNotFound(id: String)
  AlreadyStarted(id: String)
  InvalidChildSpec(reason: String)
}

pub type StartError {
  InitTimeout
  InitFailed(String)
  InitExited(process.ExitReason)
}

// Unified error type for all child operations
pub type ChildOperationError {
  Running
  Restarting
  NotFound
  SimpleOneForOne
  OtherError(reason: Dynamic)
}

pub type DeleteChildResult {
  DeleteChildOk
  DeleteChildError(reason: ChildOperationError)
}

pub type RestartChildResult {
  RestartChildOk(pid: Pid)
  RestartChildOkAlreadyStarted(pid: Pid)
  RestartChildError(reason: ChildOperationError)
}

pub type TerminateChildResult {
  TerminateChildOk
  TerminateChildError(reason: ChildOperationError)
}

pub type ChildCounts {
  ChildCounts(specs: Int, active: Int, supervisors: Int, workers: Int)
}

pub type ChildStatus {
  ChildPid(pid: Pid)
  ChildRestarting
  ChildUndefined
}

pub type ChildModules {
  ModulesDynamic
  ModulesList(modules: List(Atom))
  ModulesEmpty
}

pub type ChildInfoResult {
  ChildInfo(
    id: Dynamic,
    child: ChildStatus,
    child_type: ChildType,
    modules: ChildModules,
  )
}

// Simple child specification for common use cases
pub type SimpleChildSpec {
  SimpleChildSpec(
    id: String,
    start_module: Atom,
    start_function: Atom,
    start_args: List(Dynamic),
    restart: RestartStrategy,
    shutdown_timeout: Int,
    child_type: ChildType,
  )
}

// ============================================================================
// RESULT TYPES - These compile to tuples for Elixir interop
// ============================================================================

pub type DynamicSupervisorResult {
  DynamicSupervisorOk(pid: Pid)
  DynamicSupervisorError(reason: Dynamic)
}

pub type DynamicChildResult {
  DynamicStartChildOk(pid: Pid)
  DynamicStartChildError(reason: Dynamic)
}

pub type DynamicTerminateResult {
  DynamicTerminateChildOk
  DynamicTerminateChildError(reason: Dynamic)
}

// ============================================================================
// FFI FUNCTIONS - Using Elixir Helper Module
// ============================================================================

// Dynamic Supervisor FFI (using our Elixir helper)
@external(erlang, "Elixir.Glixir.Supervisor", "start_dynamic_supervisor")
fn start_dynamic_supervisor_ffi(options: Dynamic) -> DynamicSupervisorResult

@external(erlang, "Elixir.Glixir.Supervisor", "start_dynamic_supervisor_named")
fn start_dynamic_supervisor_named_ffi(name: String) -> DynamicSupervisorResult

@external(erlang, "Elixir.Glixir.Supervisor", "start_dynamic_supervisor_simple")
fn start_dynamic_supervisor_simple_ffi() -> DynamicSupervisorResult

@external(erlang, "Elixir.Glixir.Supervisor", "start_dynamic_child")
fn start_dynamic_child_ffi(supervisor: Pid, spec: Dynamic) -> DynamicChildResult

@external(erlang, "Elixir.Glixir.Supervisor", "terminate_dynamic_child")
fn terminate_dynamic_child_ffi(
  supervisor: Pid,
  child_pid: Pid,
) -> DynamicTerminateResult

@external(erlang, "Elixir.Glixir.Supervisor", "which_dynamic_children")
fn which_dynamic_children_ffi(supervisor: Pid) -> Dynamic

@external(erlang, "Elixir.Glixir.Supervisor", "count_dynamic_children")
fn count_dynamic_children_ffi(supervisor: Pid) -> Dynamic

// Regular Supervisor FFI (using our Elixir wrapper)
@external(erlang, "Elixir.Glixir.Supervisor", "delete_child")
fn supervisor_delete_child(
  supervisor: Pid,
  child_id: Dynamic,
) -> DeleteChildResult

@external(erlang, "Elixir.Glixir.Supervisor", "restart_child")
fn supervisor_restart_child(
  supervisor: Pid,
  child_id: Dynamic,
) -> RestartChildResult

@external(erlang, "Elixir.Glixir.Supervisor", "which_children")
fn supervisor_which_children(supervisor: Pid) -> List(ChildInfoResult)

@external(erlang, "Elixir.Glixir.Supervisor", "count_children")
fn supervisor_count_children(supervisor: Pid) -> ChildCounts

@external(erlang, "Elixir.Glixir.Supervisor", "terminate_child")
fn supervisor_terminate_child(
  supervisor: Pid,
  child_id: Dynamic,
) -> TerminateChildResult

@external(erlang, "erlang", "binary_to_atom")
fn binary_to_atom(name: String) -> Atom

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

// Helper to convert atoms to strings for the Elixir helper
fn atom_to_string(atom_val: Atom) -> String {
  atom.to_string(atom_val)
}

// Helper to convert restart strategy to string
fn restart_to_string(restart: RestartStrategy) -> String {
  case restart {
    Permanent -> "permanent"
    Temporary -> "temporary"
    Transient -> "transient"
  }
}

// Helper to convert child type to string  
fn child_type_to_string(child_type: ChildType) -> String {
  case child_type {
    Worker -> "worker"
    SupervisorChild -> "supervisor"
  }
}

// Helper to create spec map for Elixir helper
fn spec_to_map(spec: SimpleChildSpec) -> Dynamic {
  dynamic.properties([
    #(dynamic.string("id"), dynamic.string(spec.id)),
    #(
      dynamic.string("start_module"),
      dynamic.string(atom_to_string(spec.start_module)),
    ),
    #(
      dynamic.string("start_function"),
      dynamic.string(atom_to_string(spec.start_function)),
    ),
    #(dynamic.string("start_args"), dynamic.array(spec.start_args)),
    #(
      dynamic.string("restart"),
      dynamic.string(restart_to_string(spec.restart)),
    ),
    #(
      dynamic.string("shutdown"),
      dynamic.string(int.to_string(spec.shutdown_timeout)),
    ),
    #(
      dynamic.string("type"),
      dynamic.string(child_type_to_string(spec.child_type)),
    ),
  ])
}

// ============================================================================
// DYNAMIC SUPERVISOR PUBLIC FUNCTIONS
// ============================================================================

/// Start a named dynamic supervisor using our Elixir helper
pub fn start_dynamic_supervisor_named(
  name: String,
) -> Result(Supervisor, SupervisorError) {
  case start_dynamic_supervisor_named_ffi(name) {
    // We'll need to add proper decoding here
    _ -> Error(StartError("Not yet implemented - need result decoding"))
  }
}

/// Start a simple dynamic supervisor with defaults
pub fn start_dynamic_supervisor_simple() -> Result(Supervisor, SupervisorError) {
  case start_dynamic_supervisor_simple_ffi() {
    // We'll need to add proper decoding here  
    _ -> Error(StartError("Not yet implemented - need result decoding"))
  }
}

/// Start a child in a DynamicSupervisor using our simplified interface
pub fn start_dynamic_child_simple(
  supervisor: Supervisor,
  spec: SimpleChildSpec,
) -> Result(Pid, String) {
  let Supervisor(supervisor_pid) = supervisor
  let spec_map = spec_to_map(spec)

  case start_dynamic_child_ffi(supervisor_pid, spec_map) {
    // We'll need to add proper decoding here
    _ -> Error("Not yet implemented - need result decoding")
  }
}

// ============================================================================
// REGULAR SUPERVISOR PUBLIC FUNCTIONS (keeping existing interface)
// ============================================================================

/// Create a simple child specification - the easy way to define children
pub fn child_spec(
  id: String,
  module: String,
  function: String,
  args: List(Dynamic),
) -> SimpleChildSpec {
  SimpleChildSpec(
    id: id,
    start_module: binary_to_atom(module),
    start_function: binary_to_atom(function),
    start_args: args,
    restart: Permanent,
    shutdown_timeout: 5000,
    child_type: Worker,
  )
}

/// Create a child spec with custom restart strategy
pub fn child_spec_with_restart(
  id: String,
  module: String,
  function: String,
  args: List(Dynamic),
  restart: RestartStrategy,
) -> SimpleChildSpec {
  SimpleChildSpec(
    id: id,
    start_module: binary_to_atom(module),
    start_function: binary_to_atom(function),
    start_args: args,
    restart: restart,
    shutdown_timeout: 5000,
    child_type: Worker,
  )
}

/// Delete a child specification from the supervisor
pub fn delete_child(
  supervisor: Supervisor,
  child_id: String,
) -> DeleteChildResult {
  let Supervisor(pid) = supervisor
  supervisor_delete_child(pid, dynamic.string(child_id))
}

/// Restart a child process
pub fn restart_child(
  supervisor: Supervisor,
  child_id: String,
) -> RestartChildResult {
  let Supervisor(pid) = supervisor
  supervisor_restart_child(pid, dynamic.string(child_id))
}

/// Get information about all child processes
pub fn which_children(supervisor: Supervisor) -> List(ChildInfoResult) {
  let Supervisor(pid) = supervisor
  supervisor_which_children(pid)
}

/// Count children by type and status
pub fn count_children(supervisor: Supervisor) -> ChildCounts {
  let Supervisor(pid) = supervisor
  supervisor_count_children(pid)
}

/// Terminate a child process
pub fn terminate_child(
  supervisor: Supervisor,
  child_id: String,
) -> TerminateChildResult {
  let Supervisor(pid) = supervisor
  supervisor_terminate_child(pid, dynamic.string(child_id))
}

// ============================================================================
// LEGACY FUNCTIONS (keeping for compatibility)
// ============================================================================

/// Start a new dynamic supervisor with options map (legacy interface)
pub fn start_link(
  _options: List(#(String, Dynamic)),
) -> Result(Supervisor, SupervisorError) {
  // For now, just use the simple version and ignore options
  start_dynamic_supervisor_simple()
}

/// Start a basic dynamic supervisor with default one_for_one strategy
pub fn start_link_default() -> Result(Supervisor, SupervisorError) {
  start_dynamic_supervisor_simple()
}

/// Start a named dynamic supervisor (legacy interface)
pub fn start_link_named(
  name: String,
  _additional_options: List(#(String, Dynamic)),
) -> Result(Supervisor, SupervisorError) {
  start_dynamic_supervisor_named(name)
}

/// Start a child using SimpleChildSpec (legacy interface)
pub fn start_child_simple(
  supervisor: Supervisor,
  spec: SimpleChildSpec,
) -> Result(Pid, String) {
  start_dynamic_child_simple(supervisor, spec)
}
