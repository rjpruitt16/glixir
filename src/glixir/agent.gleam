import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode.{type Decoder}
import gleam/erlang/atom.{type Atom}
import gleam/erlang/process.{type Pid}
import gleam/result
import gleam/string

/// Opaque type representing an Agent process
pub opaque type Agent {
  Agent(pid: Pid)
}

/// Errors that can occur with Agents
pub type AgentError {
  StartError(reason: String)
  Timeout
  AgentDown
  DecodeError(String)
}

// FFI functions for Elixir Agent
@external(erlang, "Elixir.Agent", "start_link")
fn agent_start_link(
  fun: fn() -> a,
  options: List(Dynamic),
) -> Result(Pid, Dynamic)

@external(erlang, "Elixir.Agent", "get")
fn agent_get(agent: Pid, fun: fn(a) -> b, timeout: Int) -> Dynamic

@external(erlang, "Elixir.Agent", "update")
fn agent_update(agent: Pid, fun: fn(a) -> a, timeout: Int) -> Atom

@external(erlang, "Elixir.Agent", "get_and_update")
fn agent_get_and_update(
  agent: Pid,
  fun: fn(a) -> #(b, a),
  timeout: Int,
) -> Dynamic

@external(erlang, "Elixir.Agent", "cast")
fn agent_cast(agent: Pid, fun: fn(a) -> a) -> Atom

@external(erlang, "Elixir.Agent", "stop")
fn agent_stop(agent: Pid, reason: Atom, timeout: Int) -> Atom

/// Start a new Agent with initial state
pub fn start(initial_fun: fn() -> a) -> Result(Agent, AgentError) {
  case agent_start_link(initial_fun, []) {
    Ok(pid) -> Ok(Agent(pid))
    Error(reason) -> Error(StartError(string.inspect(reason)))
  }
}

/// Start an Agent with a registered name (now takes Atom for name)
pub fn start_named(
  name: Atom,
  initial_fun: fn() -> a,
) -> Result(Agent, AgentError) {
  let options = [
    dynamic.array([
      atom.to_dynamic(atom.create("name")),
      // still need the key atom
      atom.to_dynamic(name),
    ]),
  ]
  case agent_start_link(initial_fun, options) {
    Ok(pid) -> Ok(Agent(pid))
    Error(reason) -> Error(StartError(string.inspect(reason)))
  }
}

/// Get the current state
/// Requires a decoder for the expected type `b`.
pub fn get(
  agent: Agent,
  fun: fn(a) -> b,
  decoder: Decoder(b),
) -> Result(b, AgentError) {
  let Agent(pid) = agent
  let result_dynamic = agent_get(pid, fun, 5000)
  decode.run(result_dynamic, decoder)
  |> result.map_error(string.inspect)
  |> result.map_error(DecodeError)
}

/// Get with custom timeout
/// Requires a decoder for the expected type `b`.
pub fn get_timeout(
  agent: Agent,
  fun: fn(a) -> b,
  timeout: Int,
  decoder: Decoder(b),
) -> Result(b, AgentError) {
  let Agent(pid) = agent
  let result_dynamic = agent_get(pid, fun, timeout)
  decode.run(result_dynamic, decoder)
  |> result.map_error(string.inspect)
  |> result.map_error(DecodeError)
}

/// Update the state synchronously
pub fn update(agent: Agent, fun: fn(a) -> a) -> Result(Nil, AgentError) {
  let Agent(pid) = agent
  case atom.to_string(agent_update(pid, fun, 5000)) {
    "ok" -> Ok(Nil)
    _ -> Error(AgentDown)
  }
}

/// Update the state asynchronously
pub fn cast(agent: Agent, fun: fn(a) -> a) -> Nil {
  let Agent(pid) = agent
  let _ = agent_cast(pid, fun)
  Nil
}

/// Get and update in one operation
/// Requires a decoder for the expected type `b`.
pub fn get_and_update(
  agent: Agent,
  fun: fn(a) -> #(b, a),
  decoder: Decoder(b),
) -> Result(b, AgentError) {
  let Agent(pid) = agent
  let result_dynamic = agent_get_and_update(pid, fun, 5000)
  decode.run(result_dynamic, decoder)
  |> result.map_error(string.inspect)
  |> result.map_error(DecodeError)
}

/// Stop an Agent (now requires Atom reason)
pub fn stop(agent: Agent, reason: Atom) -> Result(Nil, AgentError) {
  let Agent(pid) = agent
  case atom.to_string(agent_stop(pid, reason, 5000)) {
    "ok" -> Ok(Nil)
    _ -> Error(AgentDown)
  }
}

/// Get the PID of an Agent
pub fn pid(agent: Agent) -> Pid {
  let Agent(p) = agent
  p
}
