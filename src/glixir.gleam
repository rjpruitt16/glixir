////
//// glixir - Unified OTP interface for Gleam, now type safe!
//// Bounded, phantom-typed supervisors! No more runtime surprises.
////

import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode.{type Decoder}
import gleam/erlang/atom
import gleam/erlang/process.{type Pid, type Subject}
import gleam/option.{None, Some}
import gleam/string
import glixir/agent
import glixir/genserver
import glixir/pubsub
import glixir/registry
import glixir/supervisor
import logging
import utils

// =====================
// PUBLIC TYPE EXPORTS
// =====================

// GENSERVER
pub type GenServer(request, reply) =
  genserver.GenServer(request, reply)

pub type GenServerError =
  genserver.GenServerError

// AGENT
pub type Agent(state) =
  agent.Agent(state)

pub type AgentError =
  agent.AgentError

// REGISTRY
pub type Registry =
  registry.Registry

pub type RegistryError =
  registry.RegistryError

// PUBSUB
pub type PubSub =
  pubsub.PubSub

pub type PubSubError =
  pubsub.PubSubError

// SUPERVISOR - BOUNDED
pub type DynamicSupervisor(child_args, child_reply) =
  supervisor.DynamicSupervisor(child_args, child_reply)

pub type ChildSpec(child_args, child_reply) =
  supervisor.ChildSpec(child_args, child_reply)

pub type StartChildResult(child_reply) =
  supervisor.StartChildResult(child_reply)

pub type RestartStrategy =
  supervisor.RestartStrategy

pub type ChildType =
  supervisor.ChildType

pub type ChildStatus =
  supervisor.ChildStatus

pub type ChildInfo(child_args, child_reply) =
  supervisor.ChildInfo(child_args, child_reply)

pub type SupervisorError =
  supervisor.SupervisorError

pub type ChildOperationError =
  supervisor.ChildOperationError

pub const permanent = supervisor.Permanent

pub const temporary = supervisor.Temporary

pub const transient = supervisor.Transient

pub const worker = supervisor.Worker

pub const supervisor_child = supervisor.SupervisorChild

// =====================
// PUBSUB
// =====================
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

// =====================
// REGISTRY
// =====================
pub fn start_registry(name: atom.Atom) -> Result(Registry, RegistryError) {
  registry.start_unique_registry(name)
}

pub fn register_subject(
  registry_name: atom.Atom,
  key: atom.Atom,
  subject: Subject(message),
) -> Result(Nil, RegistryError) {
  registry.register_subject(registry_name, key, subject)
}

pub fn lookup_subject(
  registry_name: atom.Atom,
  key: atom.Atom,
) -> Result(Subject(message), RegistryError) {
  registry.lookup_subject(registry_name, key)
}

pub fn unregister_subject(
  registry_name: atom.Atom,
  key: atom.Atom,
) -> Result(Nil, RegistryError) {
  registry.unregister_subject(registry_name, key)
}

// =====================
// SUPERVISOR (NEW BOUNDED API)
// =====================

/// Start a named dynamic supervisor (you must always specify child_args, child_reply types)
pub fn start_dynamic_supervisor_named(
  name: atom.Atom,
) -> Result(DynamicSupervisor(child_args, child_reply), SupervisorError) {
  utils.debug_log(
    logging.Info,
    "[glixir] Starting dynamic supervisor: " <> atom.to_string(name),
  )
  case supervisor.start_dynamic_supervisor_named(name) {
    Ok(sup) -> {
      utils.debug_log(
        logging.Info,
        "[glixir] Dynamic supervisor started successfully",
      )
      Ok(sup)
    }
    Error(error) -> {
      utils.debug_log(
        logging.Error,
        "[glixir] Dynamic supervisor start failed: " <> string.inspect(error),
      )
      Error(error)
    }
  }
}

/// Build a bounded, type-safe child spec
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
  supervisor.child_spec(
    id: id,
    module: module,
    function: function,
    args: args,
    restart: restart,
    shutdown_timeout: shutdown_timeout,
    child_type: child_type,
    encode: encode,
  )
}

/// Start a child process in the supervisor (requires encoder/decoder)
pub fn start_dynamic_child(
  sup: DynamicSupervisor(child_args, child_reply),
  spec: ChildSpec(child_args, child_reply),
  encode: fn(child_args) -> List(Dynamic),
  decode: fn(Dynamic) -> Result(child_reply, String),
) -> StartChildResult(child_reply) {
  utils.debug_log(logging.Info, "[glixir] Starting child: " <> spec.id)
  let result = supervisor.start_dynamic_child(sup, spec, encode, decode)
  case result {
    supervisor.ChildStarted(pid, reply) ->
      utils.debug_log(
        logging.Info,
        "[glixir] Child started successfully: " <> spec.id,
      )
    supervisor.StartChildError(e) ->
      utils.debug_log(
        logging.Error,
        "[glixir] Child start failed: " <> spec.id <> " - " <> e,
      )
  }
  result
}

pub fn terminate_dynamic_child(
  sup: DynamicSupervisor(child_args, child_reply),
  child_pid: Pid,
) -> Result(Nil, String) {
  utils.debug_log(
    logging.Info,
    "[glixir] Terminating child: " <> string.inspect(child_pid),
  )

  let result = supervisor.terminate_dynamic_child(sup, child_pid)

  case result {
    Ok(_) ->
      utils.debug_log(logging.Info, "[glixir] Child terminated successfully")
    Error(e) ->
      utils.debug_log(logging.Error, "[glixir] Child termination failed: " <> e)
  }

  result
}

/// Get all dynamic children of the supervisor
pub fn which_dynamic_children(
  sup: DynamicSupervisor(child_args, child_reply),
) -> List(Dynamic) {
  utils.debug_log(logging.Info, "[glixir] Querying dynamic children")
  supervisor.which_dynamic_children(sup)
}

/// Get the count of dynamic children
pub fn count_dynamic_children(
  sup: DynamicSupervisor(child_args, child_reply),
) -> Result(supervisor.ChildCounts, String) {
  utils.debug_log(logging.Info, "[glixir] Counting dynamic children")
  supervisor.count_dynamic_children(sup)
}

// =====================
// GENSERVER (unchanged, still type safe)
// =====================
pub fn call_genserver(
  server: GenServer(Dynamic, reply),
  request: Dynamic,
  decoder: Decoder(reply),
) -> Result(reply, GenServerError) {
  genserver.call(server, request, decoder)
}

pub fn call_genserver_timeout(
  server: GenServer(Dynamic, reply),
  request: Dynamic,
  timeout: Int,
  decoder: Decoder(reply),
) -> Result(reply, GenServerError) {
  genserver.call_timeout(server, request, timeout, decoder)
}

pub fn cast_genserver(
  server: GenServer(Dynamic, reply),
  request: Dynamic,
) -> Result(Nil, GenServerError) {
  genserver.cast(server, request)
}

pub fn start_genserver(
  module: String,
  args: Dynamic,
) -> Result(GenServer(Dynamic, reply), GenServerError) {
  genserver.start_link(module, args)
}

pub fn start_genserver_named(
  module: String,
  name: atom.Atom,
  args: Dynamic,
) -> Result(GenServer(Dynamic, reply), GenServerError) {
  genserver.start_link_named(module, atom.to_string(name), args)
}

pub fn ping_genserver(
  server: GenServer(Dynamic, reply),
  msg: Dynamic,
  decoder: Decoder(reply),
) -> Result(reply, GenServerError) {
  genserver.call(server, msg, decoder)
}

pub fn get_genserver_state(
  server: GenServer(Dynamic, reply),
  msg: Dynamic,
  decoder: Decoder(reply),
) -> Result(reply, GenServerError) {
  genserver.call(server, msg, decoder)
}

pub fn call_genserver_named(
  name: atom.Atom,
  request: Dynamic,
  decoder: Decoder(reply),
) -> Result(reply, GenServerError) {
  genserver.call_named(name, request, decoder)
}

pub fn cast_genserver_named(
  name: atom.Atom,
  request: Dynamic,
) -> Result(Nil, GenServerError) {
  genserver.cast_named(name, request)
}

pub fn lookup_genserver(
  name: atom.Atom,
) -> Result(GenServer(Dynamic, reply), GenServerError) {
  genserver.lookup_name(name)
}

pub fn stop_genserver(
  server: GenServer(Dynamic, reply),
) -> Result(Nil, GenServerError) {
  genserver.stop(server)
}

pub fn genserver_pid(server: GenServer(Dynamic, reply)) -> Pid {
  genserver.pid(server)
}

// =====================
// AGENT (unchanged, still type safe)
// =====================
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

// =====================
// MAIN
// =====================
pub fn main() {
  logging.configure()
}
