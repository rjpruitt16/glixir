import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode.{type Decoder}
import gleam/erlang/atom.{type Atom}
import gleam/erlang/process.{type Pid}
import gleam/result
import gleam/string

pub opaque type Agent(state) {
  Agent(pid: Pid)
}

pub type AgentError {
  StartError(reason: String)
  Timeout
  AgentDown
  DecodeError(String)
}

@external(erlang, "Elixir.Agent", "start_link")
fn agent_start_link(
  fun: fn() -> state,
  options: List(Dynamic),
) -> Result(Pid, Dynamic)

@external(erlang, "Elixir.Agent", "get")
fn agent_get(agent: Pid, fun: fn(state) -> a, timeout: Int) -> Dynamic

@external(erlang, "Elixir.Agent", "update")
fn agent_update(agent: Pid, fun: fn(state) -> state, timeout: Int) -> Atom

@external(erlang, "Elixir.Agent", "get_and_update")
fn agent_get_and_update(
  agent: Pid,
  fun: fn(state) -> #(a, state),
  timeout: Int,
) -> Dynamic

@external(erlang, "Elixir.Agent", "cast")
fn agent_cast(agent: Pid, fun: fn(state) -> state) -> Atom

@external(erlang, "Elixir.Agent", "stop")
fn agent_stop(agent: Pid, reason: Atom, timeout: Int) -> Atom

pub fn start(initial_fun: fn() -> state) -> Result(Agent(state), AgentError) {
  case agent_start_link(initial_fun, []) {
    Ok(pid) -> Ok(Agent(pid))
    Error(reason) -> Error(StartError(string.inspect(reason)))
  }
}

pub fn start_named(
  name: Atom,
  initial_fun: fn() -> state,
) -> Result(Agent(state), AgentError) {
  let options = [
    dynamic.array([atom.to_dynamic(atom.create("name")), atom.to_dynamic(name)]),
  ]
  case agent_start_link(initial_fun, options) {
    Ok(pid) -> Ok(Agent(pid))
    Error(reason) -> Error(StartError(string.inspect(reason)))
  }
}

pub fn get(
  agent: Agent(state),
  fun: fn(state) -> a,
  decoder: Decoder(a),
) -> Result(a, AgentError) {
  let Agent(pid) = agent
  let result_dynamic = agent_get(pid, fun, 5000)
  decode.run(result_dynamic, decoder)
  |> result.map_error(string.inspect)
  |> result.map_error(DecodeError)
}

pub fn get_timeout(
  agent: Agent(state),
  fun: fn(state) -> a,
  timeout: Int,
  decoder: Decoder(a),
) -> Result(a, AgentError) {
  let Agent(pid) = agent
  let result_dynamic = agent_get(pid, fun, timeout)
  decode.run(result_dynamic, decoder)
  |> result.map_error(string.inspect)
  |> result.map_error(DecodeError)
}

pub fn update(
  agent: Agent(state),
  fun: fn(state) -> state,
) -> Result(Nil, AgentError) {
  let Agent(pid) = agent
  case atom.to_string(agent_update(pid, fun, 5000)) {
    "ok" -> Ok(Nil)
    _ -> Error(AgentDown)
  }
}

pub fn cast(agent: Agent(state), fun: fn(state) -> state) -> Nil {
  let Agent(pid) = agent
  let _ = agent_cast(pid, fun)
  Nil
}

pub fn get_and_update(
  agent: Agent(state),
  fun: fn(state) -> #(a, state),
  decoder: Decoder(a),
) -> Result(a, AgentError) {
  let Agent(pid) = agent
  let result_dynamic = agent_get_and_update(pid, fun, 5000)
  decode.run(result_dynamic, decoder)
  |> result.map_error(string.inspect)
  |> result.map_error(DecodeError)
}

pub fn stop(agent: Agent(state), reason: Atom) -> Result(Nil, AgentError) {
  let Agent(pid) = agent
  case atom.to_string(agent_stop(pid, reason, 5000)) {
    "ok" -> Ok(Nil)
    _ -> Error(AgentDown)
  }
}

pub fn pid(agent: Agent(state)) -> Pid {
  let Agent(p) = agent
  p
}
