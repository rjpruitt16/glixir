//// glixir - Seamless OTP interop between Gleam and Elixir/Erlang
//// 
//// This module provides a unified API for working with OTP processes from Gleam.
//// Import this module to get access to Supervisors, GenServers, and Agents.

import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode.{type Decoder}
import gleam/erlang/atom
import gleam/erlang/process.{type Pid}
import gleam/int
import gleam/io
import gleam/list
import gleam/string
import glixir/agent
import glixir/genserver
import glixir/supervisor

// Re-export main types
pub type GenServer =
  genserver.GenServer

pub type Agent =
  agent.Agent

pub type Supervisor =
  supervisor.Supervisor

pub type SimpleChildSpec =
  supervisor.SimpleChildSpec

pub type RestartStrategy =
  supervisor.RestartStrategy

pub type ChildType =
  supervisor.ChildType

// Re-export constructor values for convenience 
pub const permanent = supervisor.Permanent

pub const temporary = supervisor.Temporary

pub const transient = supervisor.Transient

pub const worker = supervisor.Worker

pub const supervisor_child = supervisor.SupervisorChild

// Re-export error types
pub type GenServerError =
  genserver.GenServerError

pub type AgentError =
  agent.AgentError

pub type SupervisorError =
  supervisor.SupervisorError

//
// SUPERVISOR FUNCTIONS
//

/// Start a supervisor with default options
pub fn start_supervisor() -> Result(Supervisor, SupervisorError) {
  supervisor.start_link_default()
}

/// Start a simple supervisor with defaults
pub fn start_supervisor_simple() -> Result(Supervisor, SupervisorError) {
  io.println("DEBUG: start_supervisor_simple called")

  let result = supervisor.start_dynamic_supervisor_simple()
  case result {
    Ok(sup) -> {
      io.println("DEBUG: simple supervisor started successfully")
      Ok(sup)
    }
    Error(error) -> {
      io.println(
        "DEBUG: simple supervisor start failed with error: "
        <> string.inspect(error),
      )
      Error(error)
    }
  }
}

/// Start a named supervisor using DynamicSupervisor
pub fn start_supervisor_named(
  name: String,
  _additional_options: List(#(String, Dynamic)),
) -> Result(Supervisor, SupervisorError) {
  io.println("DEBUG: start_supervisor_named called with name: " <> name)

  let result = supervisor.start_dynamic_supervisor_named(name)
  case result {
    Ok(sup) -> {
      io.println("DEBUG: supervisor started successfully")
      Ok(sup)
    }
    Error(error) -> {
      io.println(
        "DEBUG: supervisor start failed with error: " <> string.inspect(error),
      )
      Error(error)
    }
  }
}

/// Create a child specification
pub fn child_spec(
  id id: String,
  module module: String,
  function function: String,
  args args: List(Dynamic),
) -> SimpleChildSpec {
  supervisor.child_spec(id, module, function, args)
}

/// Start a child process in the supervisor
pub fn start_child(
  supervisor: Supervisor,
  spec: SimpleChildSpec,
) -> Result(Pid, String) {
  io.println("DEBUG: start_child called with spec id: " <> spec.id)

  let result = supervisor.start_child_simple(supervisor, spec)
  case result {
    Ok(pid) -> {
      io.println("DEBUG: child started successfully with PID")
      Ok(pid)
    }
    Error(error) -> {
      io.println("DEBUG: child start failed with error: " <> error)
      Error(error)
    }
  }
}

/// Terminate a child process
pub fn terminate_child(
  supervisor: Supervisor,
  child_id: String,
) -> Result(Nil, supervisor.ChildOperationError) {
  case supervisor.terminate_child(supervisor, child_id) {
    supervisor.TerminateChildOk -> Ok(Nil)
    supervisor.TerminateChildError(error) -> Error(error)
  }
}

/// Restart a child process
pub fn restart_child(
  supervisor: Supervisor,
  child_id: String,
) -> Result(Pid, supervisor.ChildOperationError) {
  case supervisor.restart_child(supervisor, child_id) {
    supervisor.RestartChildOk(pid) -> Ok(pid)
    supervisor.RestartChildOkAlreadyStarted(pid) -> Ok(pid)
    supervisor.RestartChildError(error) -> Error(error)
  }
}

/// Delete a child specification from the supervisor
pub fn delete_child(
  supervisor: Supervisor,
  child_id: String,
) -> Result(Nil, supervisor.ChildOperationError) {
  case supervisor.delete_child(supervisor, child_id) {
    supervisor.DeleteChildOk -> Ok(Nil)
    supervisor.DeleteChildError(error) -> Error(error)
  }
}

/// Get list of child processes
pub fn which_children(
  supervisor: Supervisor,
) -> List(supervisor.ChildInfoResult) {
  supervisor.which_children(supervisor)
}

/// Count children by status
pub fn count_children(supervisor: Supervisor) -> supervisor.ChildCounts {
  supervisor.count_children(supervisor)
}

//
// GENSERVER FUNCTIONS
//

/// Start a GenServer using Module.start_link/1
pub fn start_genserver(
  module: String,
  args: a,
) -> Result(GenServer, GenServerError) {
  genserver.start_link(module, args)
}

/// Start a named GenServer
pub fn start_genserver_named(
  module: String,
  name: String,
  args: a,
) -> Result(GenServer, GenServerError) {
  genserver.start_link_named(module, name, args)
}

/// Send a synchronous call to the GenServer (5s timeout)
pub fn call_genserver(
  server: GenServer,
  request: a,
) -> Result(b, GenServerError) {
  genserver.call(server, request)
}

/// Send a synchronous call with custom timeout
pub fn call_genserver_timeout(
  server: GenServer,
  request: a,
  timeout: Int,
) -> Result(b, GenServerError) {
  genserver.call_timeout(server, request, timeout)
}

/// Call a named GenServer
pub fn call_genserver_named(
  name: String,
  request: a,
) -> Result(b, GenServerError) {
  genserver.call_named(name, request)
}

/// Send an asynchronous cast to the GenServer
pub fn cast_genserver(
  server: GenServer,
  request: a,
) -> Result(Nil, GenServerError) {
  genserver.cast(server, request)
}

/// Cast to a named GenServer
pub fn cast_genserver_named(
  name: String,
  request: a,
) -> Result(Nil, GenServerError) {
  genserver.cast_named(name, request)
}

/// Look up a GenServer by registered name
pub fn lookup_genserver(name: String) -> Result(GenServer, GenServerError) {
  genserver.lookup_name(name)
}

/// Stop a GenServer gracefully
pub fn stop_genserver(server: GenServer) -> Result(Nil, GenServerError) {
  genserver.stop(server)
}

/// Get the PID of a GenServer
pub fn genserver_pid(server: GenServer) -> Pid {
  genserver.pid(server)
}

//
// AGENT FUNCTIONS
//

/// Start a new Agent with initial state
pub fn start_agent(initial_fun: fn() -> a) -> Result(Agent, AgentError) {
  agent.start(initial_fun)
}

/// Start an Agent with a name
pub fn start_agent_named(
  name: String,
  initial_fun: fn() -> a,
) -> Result(Agent, AgentError) {
  agent.start_named(name, initial_fun)
}

/// Get the current state from an Agent
pub fn get_agent(
  agent: Agent,
  fun: fn(a) -> b,
  decoder: Decoder(b),
) -> Result(b, AgentError) {
  agent.get(agent, fun, decoder)
}

/// Get with custom timeout
pub fn get_agent_timeout(
  agent: Agent,
  fun: fn(a) -> b,
  timeout: Int,
  decoder: Decoder(b),
) -> Result(b, AgentError) {
  agent.get_timeout(agent, fun, timeout, decoder)
}

/// Update the Agent state synchronously
pub fn update_agent(agent: Agent, fun: fn(a) -> a) -> Result(Nil, AgentError) {
  agent.update(agent, fun)
}

/// Update the Agent state asynchronously
pub fn cast_agent(agent: Agent, fun: fn(a) -> a) -> Nil {
  agent.cast(agent, fun)
}

/// Get and update in one operation
pub fn get_and_update_agent(
  agent: Agent,
  fun: fn(a) -> #(b, a),
  decoder: Decoder(b),
) -> Result(b, AgentError) {
  agent.get_and_update(agent, fun, decoder)
}

/// Stop an Agent
pub fn stop_agent(agent: Agent) -> Result(Nil, AgentError) {
  agent.stop(agent)
}

/// Get the PID of an Agent
pub fn agent_pid(agent: Agent) -> Pid {
  agent.pid(agent)
}

//
// CONVENIENCE FUNCTIONS
//

/// Create a simple worker child spec with defaults
pub fn worker_spec(
  id: String,
  module: String,
  args: List(Dynamic),
) -> SimpleChildSpec {
  supervisor.SimpleChildSpec(
    id: id,
    start_module: atom.create(module),
    start_function: atom.create("start_link"),
    start_args: args,
    restart: permanent,
    child_type: worker,
    shutdown_timeout: 5000,
  )
}

/// Create a supervisor child spec
pub fn supervisor_spec(
  id: String,
  module: String,
  args: List(Dynamic),
) -> SimpleChildSpec {
  supervisor.SimpleChildSpec(
    id: id,
    start_module: atom.create(module),
    start_function: atom.create("start_link"),
    start_args: args,
    restart: permanent,
    child_type: supervisor_child,
    shutdown_timeout: 5000,
  )
}
