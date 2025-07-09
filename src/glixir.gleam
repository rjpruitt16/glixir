//// 
//// This module provides a unified API for working with OTP processes from Gleam.
//// Now includes registry support for Subject lookup.

/// glixir - Enhanced with Subject support for proper message passing
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode.{type Decoder}
import gleam/erlang/atom
import gleam/erlang/process.{type Pid, type Subject}
import gleam/string
import glixir/agent
import glixir/genserver
import glixir/pubsub
import glixir/registry
import glixir/supervisor.{type ChildCounts}
import logging

// Re-export main types
pub type GenServer =
  genserver.GenServer

pub type Agent(state) =
  agent.Agent(state)

pub type Supervisor =
  supervisor.Supervisor

pub type Registry =
  registry.Registry

pub type SimpleChildSpec =
  supervisor.SimpleChildSpec

pub type RestartStrategy =
  supervisor.RestartStrategy

pub type ChildType =
  supervisor.ChildType

pub type PubSub =
  pubsub.PubSub

pub type PubSubError =
  pubsub.PubSubError

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

pub type RegistryError =
  registry.RegistryError

// 
// PUBSUB FUNCTIONS
//

pub fn start_pubsub(name: String) -> Result(PubSub, PubSubError) {
  pubsub.start_pubsub(name)
}

pub fn pubsub_subscribe(
  pubsub_name: String,
  topic: String,
) -> Result(Nil, PubSubError) {
  pubsub.subscribe(pubsub_name, topic)
}

pub fn pubsub_broadcast(
  pubsub_name: String,
  topic: String,
  message: Dynamic,
) -> Result(Nil, PubSubError) {
  pubsub.broadcast(pubsub_name, topic, message)
}

pub fn pubsub_unsubscribe(
  pubsub_name: String,
  topic: String,
) -> Result(Nil, PubSubError) {
  pubsub.unsubscribe(pubsub_name, topic)
}

//
// REGISTRY FUNCTIONS
//

/// Start a unique registry for Subject lookup
pub fn start_registry(name: atom.Atom) -> Result(Registry, RegistryError) {
  logging.log(logging.Debug, "Starting registry: " <> atom.to_string(name))
  registry.start_unique_registry(name)
}

/// Register a Subject with a key in the registry
pub fn register_subject(
  registry_name: atom.Atom,
  key: atom.Atom,
  subject: Subject(message),
) -> Result(Nil, RegistryError) {
  logging.log(logging.Debug, "Registering subject: " <> atom.to_string(key))
  registry.register_subject(registry_name, key, subject)
}

/// Look up a Subject by key in the registry
pub fn lookup_subject(
  registry_name: atom.Atom,
  key: atom.Atom,
) -> Result(Subject(message), RegistryError) {
  logging.log(logging.Debug, "Looking up subject: " <> atom.to_string(key))
  registry.lookup_subject(registry_name, key)
}

/// Unregister a Subject from the registry
pub fn unregister_subject(
  registry_name: atom.Atom,
  key: atom.Atom,
) -> Result(Nil, RegistryError) {
  logging.log(logging.Debug, "Unregistering subject: " <> atom.to_string(key))
  registry.unregister_subject(registry_name, key)
}

//
// SUPERVISOR FUNCTIONS
//

/// Start a supervisor with default options
pub fn start_supervisor() -> Result(Supervisor, SupervisorError) {
  supervisor.start_dynamic_supervisor_simple()
}

/// Start a simple supervisor with defaults
pub fn start_supervisor_simple() -> Result(Supervisor, SupervisorError) {
  logging.log(logging.Debug, "Starting simple supervisor")

  let result = supervisor.start_dynamic_supervisor_simple()
  case result {
    Ok(sup) -> {
      logging.log(logging.Info, "Simple supervisor started successfully")
      Ok(sup)
    }
    Error(error) -> {
      logging.log(
        logging.Error,
        "Simple supervisor start failed: " <> string.inspect(error),
      )
      Error(error)
    }
  }
}

/// Start a named supervisor using DynamicSupervisor
pub fn start_supervisor_named(
  name: atom.Atom,
  _additional_options: List(#(String, Dynamic)),
) -> Result(Supervisor, SupervisorError) {
  logging.log(
    logging.Debug,
    "Starting named supervisor: " <> atom.to_string(name),
  )

  let result = supervisor.start_dynamic_supervisor_named(name)
  case result {
    Ok(sup) -> {
      logging.log(
        logging.Info,
        "Named supervisor '" <> atom.to_string(name) <> "' started successfully",
      )
      Ok(sup)
    }
    Error(error) -> {
      logging.log(
        logging.Error,
        "Named supervisor '"
          <> atom.to_string(name)
          <> "' start failed: "
          <> string.inspect(error),
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
  supervisor_instance: Supervisor,
  spec: SimpleChildSpec,
) -> Result(Pid, String) {
  logging.log(logging.Debug, "Starting child with id: " <> spec.id)

  let result = supervisor.start_dynamic_child(supervisor_instance, spec)
  case result {
    Ok(pid) -> {
      logging.log(
        logging.Info,
        "Child '" <> spec.id <> "' started successfully",
      )
      Ok(pid)
    }
    Error(error) -> {
      logging.log(
        logging.Error,
        "Child '" <> spec.id <> "' start failed: " <> error,
      )
      Error(error)
    }
  }
}

/// Terminate a child process
pub fn terminate_child(
  supervisor_instance: Supervisor,
  child_id: String,
) -> Result(Nil, supervisor.ChildOperationError) {
  logging.log(logging.Debug, "Terminating child: " <> child_id)

  case supervisor.terminate_child(supervisor_instance, child_id) {
    supervisor.TerminateChildOk -> {
      logging.log(
        logging.Info,
        "Child '" <> child_id <> "' terminated successfully",
      )
      Ok(Nil)
    }
    supervisor.TerminateChildError(error) -> {
      logging.log(
        logging.Error,
        "Failed to terminate child '" <> child_id <> "'",
      )
      Error(error)
    }
  }
}

/// Restart a child process
pub fn restart_child(
  supervisor_instance: Supervisor,
  child_id: String,
) -> Result(Pid, supervisor.ChildOperationError) {
  logging.log(logging.Debug, "Restarting child: " <> child_id)

  case supervisor.restart_child(supervisor_instance, child_id) {
    supervisor.RestartChildOk(pid) -> {
      logging.log(
        logging.Info,
        "Child '" <> child_id <> "' restarted successfully",
      )
      Ok(pid)
    }
    supervisor.RestartChildOkAlreadyStarted(pid) -> {
      logging.log(
        logging.Info,
        "Child '" <> child_id <> "' was already started",
      )
      Ok(pid)
    }
    supervisor.RestartChildError(error) -> {
      logging.log(logging.Error, "Failed to restart child '" <> child_id <> "'")
      Error(error)
    }
  }
}

/// Delete a child specification from the supervisor
pub fn delete_child(
  supervisor_instance: Supervisor,
  child_id: String,
) -> Result(Nil, supervisor.ChildOperationError) {
  logging.log(logging.Debug, "Deleting child spec: " <> child_id)

  case supervisor.delete_child(supervisor_instance, child_id) {
    supervisor.DeleteChildOk -> {
      logging.log(
        logging.Info,
        "Child spec '" <> child_id <> "' deleted successfully",
      )
      Ok(Nil)
    }
    supervisor.DeleteChildError(error) -> {
      logging.log(
        logging.Error,
        "Failed to delete child spec '" <> child_id <> "'",
      )
      Error(error)
    }
  }
}

/// Get list of child processes
pub fn which_children(
  supervisor_instance: Supervisor,
) -> List(supervisor.ChildInfoResult) {
  logging.log(logging.Debug, "Querying supervisor children")
  supervisor.which_dynamic_children(supervisor_instance)
}

/// Count children by status
pub fn count_children(supervisor_instance: Supervisor) -> ChildCounts {
  logging.log(logging.Debug, "Counting supervisor children")
  supervisor.count_dynamic_children(supervisor_instance)
}

//
// GENSERVER FUNCTIONS
//

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

/// Send an asynchronous cast to the GenServer
pub fn cast_genserver(
  server: GenServer,
  request: a,
) -> Result(Nil, GenServerError) {
  genserver.cast(server, request)
}

/// Start a GenServer (Elixir module name, args)
pub fn start_genserver(
  module: String,
  args: a,
) -> Result(GenServer, GenServerError) {
  genserver.start_link(module, args)
}

/// Start a named GenServer (Elixir module name, atom name, args)
pub fn start_genserver_named(
  module: String,
  name: atom.Atom,
  args: a,
) -> Result(GenServer, GenServerError) {
  genserver.start_link_named(module, atom.to_string(name), args)
}

/// Start a simple GenServer with one argument
pub fn start_simple_genserver(
  module: String,
  initial_state: String,
) -> Result(GenServer, GenServerError) {
  genserver.start_link(module, initial_state)
}

/// Ping a GenServer (user must pass atom)
pub fn ping_genserver(
  server: GenServer,
  msg: atom.Atom,
) -> Result(Dynamic, GenServerError) {
  genserver.call(server, msg)
}

/// Get state (user must pass atom)
pub fn get_genserver_state(
  server: GenServer,
  msg: atom.Atom,
) -> Result(Dynamic, GenServerError) {
  genserver.call(server, msg)
}

/// Call a named GenServer
pub fn call_genserver_named(
  name: atom.Atom,
  request: a,
) -> Result(b, GenServerError) {
  genserver.call_named(name, request)
}

/// Cast to a named GenServer
pub fn cast_genserver_named(
  name: atom.Atom,
  request: a,
) -> Result(Nil, GenServerError) {
  genserver.cast_named(name, request)
}

/// Look up a GenServer by registered Atom name
pub fn lookup_genserver(name: atom.Atom) -> Result(GenServer, GenServerError) {
  genserver.lookup_name(name)
}

/// Stop a GenServer gracefully
pub fn stop_genserver(server: GenServer) -> Result(Nil, GenServerError) {
  logging.log(logging.Debug, "Stopping GenServer")
  genserver.stop(server)
}

/// Get the PID of a GenServer
pub fn genserver_pid(server: GenServer) -> Pid {
  genserver.pid(server)
}

//
// AGENT FUNCTIONS
//

pub fn start_agent(state: fn() -> a) -> Result(Agent(a), AgentError) {
  agent.start(state)
}

pub fn get_agent(
  agent: Agent(a),
  fun: fn(a) -> b,
  decoder: Decoder(b),
) -> Result(b, AgentError) {
  agent.get(agent, fun, decoder)
}

pub fn get_agent_timeout(
  agent: Agent(a),
  fun: fn(a) -> b,
  timeout: Int,
  decoder: Decoder(b),
) -> Result(b, AgentError) {
  agent.get_timeout(agent, fun, timeout, decoder)
}

pub fn update_agent(agent: Agent(a), fun: fn(a) -> a) -> Result(Nil, AgentError) {
  agent.update(agent, fun)
}

pub fn cast_agent(agent: Agent(a), fun: fn(a) -> a) -> Nil {
  agent.cast(agent, fun)
}

pub fn get_and_update_agent(
  agent: Agent(a),
  fun: fn(a) -> #(b, a),
  decoder: Decoder(b),
) -> Result(b, AgentError) {
  agent.get_and_update(agent, fun, decoder)
}

pub fn stop_agent(agent: Agent(a), reason: atom.Atom) -> Result(Nil, AgentError) {
  agent.stop(agent, reason)
}

pub fn agent_pid(agent: Agent(a)) -> Pid {
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

/// Main function for when glixir is run directly (demo/testing)
pub fn main() {
  logging.configure()
}
