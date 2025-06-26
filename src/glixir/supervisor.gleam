//// Dynamic supervisor support for runtime process management
//// 
//// This module provides a Gleam-friendly interface to Elixir's DynamicSupervisor,
//// using our Elixir helper module for clean data conversion.

import gleam/dynamic.{type Dynamic}
import gleam/erlang/atom.{type Atom}
import gleam/erlang/process.{type Pid}
import gleam/int
import gleam/string

/// Opaque type representing a supervisor process
pub opaque type Supervisor {
  Supervisor(pid: Pid)
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
// RESULT TYPES - These match the Elixir helper return tuples
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
fn which_dynamic_children_ffi(supervisor: Pid) -> List(ChildInfoResult)

@external(erlang, "Elixir.Glixir.Supervisor", "count_dynamic_children")
fn count_dynamic_children_ffi(supervisor: Pid) -> ChildCounts

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
      dynamic.string(atom.to_string(spec.start_module)),
    ),
    #(
      dynamic.string("start_function"),
      dynamic.string(atom.to_string(spec.start_function)),
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

/// Start a named dynamic supervisor
pub fn start_dynamic_supervisor_named(
  name: String,
) -> Result(Supervisor, SupervisorError) {
  case start_dynamic_supervisor_named_ffi(name) {
    DynamicSupervisorOk(pid) -> Ok(Supervisor(pid))
    DynamicSupervisorError(reason) -> Error(StartError(string.inspect(reason)))
  }
}

/// Start a simple dynamic supervisor with defaults
pub fn start_dynamic_supervisor_simple() -> Result(Supervisor, SupervisorError) {
  case start_dynamic_supervisor_simple_ffi() {
    DynamicSupervisorOk(pid) -> Ok(Supervisor(pid))
    DynamicSupervisorError(reason) -> Error(StartError(string.inspect(reason)))
  }
}

/// Start a child in a DynamicSupervisor
pub fn start_dynamic_child(
  supervisor: Supervisor,
  spec: SimpleChildSpec,
) -> Result(Pid, String) {
  let Supervisor(supervisor_pid) = supervisor
  let spec_map = spec_to_map(spec)

  case start_dynamic_child_ffi(supervisor_pid, spec_map) {
    DynamicStartChildOk(pid) -> Ok(pid)
    DynamicStartChildError(reason) -> Error(string.inspect(reason))
  }
}

/// Terminate a dynamic child process
pub fn terminate_dynamic_child(
  supervisor: Supervisor,
  child_pid: Pid,
) -> Result(Nil, String) {
  let Supervisor(supervisor_pid) = supervisor

  case terminate_dynamic_child_ffi(supervisor_pid, child_pid) {
    DynamicTerminateChildOk -> Ok(Nil)
    DynamicTerminateChildError(reason) -> Error(string.inspect(reason))
  }
}

/// Get information about all dynamic children
pub fn which_dynamic_children(supervisor: Supervisor) -> List(ChildInfoResult) {
  let Supervisor(pid) = supervisor
  which_dynamic_children_ffi(pid)
}

/// Count dynamic children by type and status
pub fn count_dynamic_children(supervisor: Supervisor) -> ChildCounts {
  let Supervisor(pid) = supervisor
  count_dynamic_children_ffi(pid)
}

// ============================================================================
// CHILD SPECIFICATION FUNCTIONS
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

// ============================================================================
// REGULAR SUPERVISOR FUNCTIONS (for non-dynamic supervisors)
// ============================================================================

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

/// Terminate a child process
pub fn terminate_child(
  supervisor: Supervisor,
  child_id: String,
) -> TerminateChildResult {
  let Supervisor(pid) = supervisor
  supervisor_terminate_child(pid, dynamic.string(child_id))
}
