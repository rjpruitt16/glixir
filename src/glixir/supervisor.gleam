//// Type-safe, bounded DynamicSupervisor interop for Gleam/Elixir
////
//// This module provides a *phantom-typed* interface to Elixir DynamicSupervisor.
//// All child processes are parameterized by their `args` and `reply` types,
//// so misuse is a compile error, not a runtime surprise.

import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/erlang/atom.{type Atom}
import gleam/erlang/process.{type Pid}
import gleam/int
import gleam/list
import gleam/option.{type Option}
import gleam/string
import logging
import utils

/// Opaque type representing a supervisor process
pub opaque type DynamicSupervisor(child_args, child_reply) {
  DynamicSupervisor(pid: Pid)
}

/// Strongly-typed child specification
pub type ChildSpec(child_args, child_reply) {
  ChildSpec(
    id: String,
    start_module: Atom,
    start_function: Atom,
    start_args: child_args,
    // Use a record, tuple, or concrete type!
    restart: RestartStrategy,
    shutdown_timeout: Int,
    child_type: ChildType,
  )
}

/// Child restart strategy
pub type RestartStrategy {
  Permanent
  Temporary
  Transient
}

/// Type of child process
pub type ChildType {
  Worker
  SupervisorChild
}

/// Supervisor errors
pub type SupervisorError {
  StartError(String)
  ChildStartError(String, String)
  ChildNotFound(String)
  AlreadyStarted(String)
  InvalidChildSpec(String)
}

/// Strongly-typed result when starting a child
pub type StartChildResult(child_reply) {
  ChildStarted(Pid, child_reply)
  StartChildError(String)
}

/// Child status for introspection
pub type ChildStatus {
  ChildPid(Pid)
  ChildRestarting
  ChildUndefined
}

/// Supervisor child info (partial for demo—expand as needed)
pub type ChildInfo(child_args, child_reply) {
  ChildInfo(
    id: String,
    pid: Option(Pid),
    child_type: ChildType,
    status: ChildStatus,
    args: child_args,
    // Phantom only, not runtime-inspected
    reply: child_reply,
    // Phantom only, not runtime-inspected
  )
}

pub type ChildCounts {
  ChildCounts(specs: Int, active: Int, supervisors: Int, workers: Int)
}

/// Opaque error type for child operations (for completeness)
pub type ChildOperationError {
  Running
  Restarting
  NotFound
  SimpleOneForOne
  OtherError(String)
}

// Add these result types for FFI pattern matching
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

// ============ FFI BINDINGS ==============
@external(erlang, "Elixir.Glixir.Supervisor", "start_dynamic_supervisor_named")
fn start_dynamic_supervisor_named_ffi(name: String) -> DynamicSupervisorResult

@external(erlang, "Elixir.Glixir.Supervisor", "start_dynamic_child")
fn start_dynamic_child_ffi(pid: Pid, spec: Dynamic) -> DynamicChildResult

@external(erlang, "Elixir.Glixir.Supervisor", "terminate_dynamic_child")
fn terminate_dynamic_child_ffi(
  pid: Pid,
  child_pid: Pid,
) -> DynamicTerminateResult

@external(erlang, "Elixir.Glixir.Supervisor", "which_dynamic_children")
fn which_dynamic_children_ffi(pid: Pid) -> List(Dynamic)

// introspection only

@external(erlang, "Elixir.Glixir.Supervisor", "count_dynamic_children")
fn count_dynamic_children_ffi(pid: Pid) -> Dynamic

// should wrap to ChildCounts

@external(erlang, "erlang", "binary_to_atom")
fn binary_to_atom(name: String) -> Atom

// ============ HELPERS ==============

fn restart_to_string(r: RestartStrategy) -> String {
  case r {
    Permanent -> "permanent"
    Temporary -> "temporary"
    Transient -> "transient"
  }
}

fn child_type_to_string(t: ChildType) -> String {
  case t {
    Worker -> "worker"
    SupervisorChild -> "supervisor"
  }
}

// Use a generic encoder for child args
pub fn encode_child_args(child_args: a) -> List(Dynamic) {
  // Users should provide their own encoder! (or you could supply some common ones)
  []
}

// ============ PUBLIC API ==============

/// Start a named dynamic supervisor with bounded child types
pub fn start_dynamic_supervisor_named(
  name: Atom,
) -> Result(DynamicSupervisor(child_args, child_reply), SupervisorError) {
  utils.debug_log(
    logging.Debug,
    "[supervisor] Starting supervisor: " <> atom.to_string(name),
  )

  case start_dynamic_supervisor_named_ffi(atom.to_string(name)) {
    DynamicSupervisorOk(pid) -> {
      utils.debug_log(
        logging.Info,
        "[supervisor] Supervisor started successfully",
      )
      Ok(DynamicSupervisor(pid))
    }
    DynamicSupervisorError(reason) -> {
      utils.debug_log(logging.Error, "[supervisor] Supervisor start failed")
      Error(StartError(string.inspect(reason)))
    }
  }
}

/// Build a type-safe child spec  
pub fn child_spec(
  id id: String,
  module module: String,
  function function: String,
  args args: child_args,
  restart restart: RestartStrategy,
  shutdown_timeout shutdown_timeout: Int,
  child_type child_type: ChildType,
  encode encode: fn(child_args) -> List(Dynamic),
) -> ChildSpec(child_args, child_reply) {
  ChildSpec(
    id,
    binary_to_atom(module),
    binary_to_atom(function),
    args,
    restart,
    shutdown_timeout,
    child_type,
  )
}

/// Build a dynamic spec map for Elixir
fn spec_to_map(
  id: String,
  m: Atom,
  f: Atom,
  args: List(Dynamic),
  restart: RestartStrategy,
  shutdown: Int,
  child_type: ChildType,
) -> Dynamic {
  dynamic.properties([
    #(dynamic.string("id"), dynamic.string(id)),
    #(dynamic.string("start_module"), dynamic.string(atom.to_string(m))),
    #(dynamic.string("start_function"), dynamic.string(atom.to_string(f))),
    #(dynamic.string("start_args"), dynamic.array(args)),
    #(dynamic.string("restart"), dynamic.string(restart_to_string(restart))),
    #(dynamic.string("shutdown"), dynamic.string(int.to_string(shutdown))),
    #(dynamic.string("type"), dynamic.string(child_type_to_string(child_type))),
  ])
}

/// Start a child with typed args and replies
pub fn start_dynamic_child(
  supervisor: DynamicSupervisor(child_args, child_reply),
  spec: ChildSpec(child_args, child_reply),
  encode: fn(child_args) -> List(Dynamic),
  decode: fn(Dynamic) -> Result(child_reply, String),
) -> StartChildResult(child_reply) {
  let DynamicSupervisor(pid) = supervisor
  let ChildSpec(id, m, f, args, restart, timeout, type_) = spec

  utils.debug_log(logging.Debug, "[supervisor] Starting child: " <> id)

  let spec_map = spec_to_map(id, m, f, encode(args), restart, timeout, type_)
  case start_dynamic_child_ffi(pid, spec_map) {
    DynamicStartChildOk(child_pid) ->
      case decode(dynamic.string("ok")) {
        Ok(child_reply) -> {
          utils.debug_log(
            logging.Info,
            "[supervisor] Child started successfully: " <> id,
          )
          ChildStarted(child_pid, child_reply)
        }
        Error(e) -> {
          utils.debug_log(
            logging.Error,
            "[supervisor] Child decode failed: " <> e,
          )
          StartChildError(e)
        }
      }
    DynamicStartChildError(reason) -> {
      utils.debug_log(logging.Error, "[supervisor] Child start failed: " <> id)
      StartChildError(string.inspect(reason))
    }
  }
}

/// Terminate a child (by pid)
pub fn terminate_dynamic_child(
  supervisor: DynamicSupervisor(child_args, child_reply),
  child_pid: Pid,
) -> Result(Nil, String) {
  let DynamicSupervisor(pid) = supervisor
  utils.debug_log(
    logging.Debug,
    "[supervisor] Terminating child: " <> string.inspect(child_pid),
  )

  // Call the FFI directly and handle the result
  let ffi_result = terminate_dynamic_child_ffi(pid, child_pid)
  utils.debug_log(
    logging.Debug,
    "[supervisor] FFI result: " <> string.inspect(ffi_result),
  )

  // Use string matching as a workaround for the pattern matching bug
  let result_string = string.inspect(ffi_result)
  case result_string {
    "DynamicTerminateChildOk()" -> {
      utils.debug_log(
        logging.Info,
        "[supervisor] Child terminated successfully",
      )
      Ok(Nil)
    }
    _ -> {
      utils.debug_log(logging.Error, "[supervisor] Child termination failed")
      Error("FFI returned unexpected result: " <> result_string)
    }
  }
}

/// Returns all dynamic children as a list of Dynamic.
/// You might want to write a real decoder for full type-safety!
pub fn which_dynamic_children(
  supervisor: DynamicSupervisor(child_args, child_reply),
) -> List(Dynamic) {
  let DynamicSupervisor(pid) = supervisor
  utils.debug_log(logging.Debug, "[supervisor] Querying children")
  let result = which_dynamic_children_ffi(pid)
  utils.debug_log(
    logging.Debug,
    "[supervisor] Found " <> int.to_string(list.length(result)) <> " children",
  )
  result
}

fn child_counts_decoder() -> decode.Decoder(ChildCounts) {
  // This is idiomatic Gleam "record decoder" syntax
  use specs <- decode.field("specs", decode.int)
  use active <- decode.field("active", decode.int)
  use supervisors <- decode.field("supervisors", decode.int)
  use workers <- decode.field("workers", decode.int)
  decode.success(ChildCounts(specs, active, supervisors, workers))
}

pub fn count_dynamic_children(
  supervisor: DynamicSupervisor(child_args, child_reply),
) -> Result(ChildCounts, String) {
  let child_counts_decoder = {
    use specs <- decode.field("specs", decode.int)
    use active <- decode.field("active", decode.int)
    use supervisors <- decode.field("supervisors", decode.int)
    use workers <- decode.field("workers", decode.int)
    decode.success(ChildCounts(specs, active, supervisors, workers))
  }
  let DynamicSupervisor(pid) = supervisor
  utils.debug_log(logging.Debug, "[supervisor] Counting children")
  let result_dynamic = count_dynamic_children_ffi(pid)
  case decode.run(result_dynamic, child_counts_decoder) {
    Ok(counts) -> {
      utils.debug_log(
        logging.Debug,
        "[supervisor] Child counts retrieved successfully",
      )
      Ok(counts)
    }
    Error(errors) -> {
      utils.debug_log(logging.Error, "[supervisor] Child count decode failed")
      Error("decode error: " <> string.inspect(errors))
    }
  }
}
