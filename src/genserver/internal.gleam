import genserver/types.{
  type Agent, type GenServer, type GenServerError, Agent, GenServer,
}
import gleam/erlang/atom
import gleam/erlang/process

// External functions for Erlang interop
@external(erlang, "erlang", "send")
pub fn erlang_send(pid: process.Pid, message: a) -> a

@external(erlang, "erlang", "binary_to_atom")
pub fn binary_to_atom(binary: String) -> atom.Atom

@external(erlang, "erlang", "apply")
fn erlang_apply(
  module: atom.Atom,
  function: atom.Atom,
  args: List(a),
) -> Result(b, atom.Atom)

@external(erlang, "gen_server", "start_link")
fn gen_server_start_link(
  module: atom.Atom,
  args: a,
  options: List(b),
) -> Result(process.Pid, atom.Atom)

// Agent external functions
@external(erlang, "Elixir.Agent", "start_link")
fn agent_start_link(initial_fun: fn() -> a) -> Result(process.Pid, atom.Atom)

@external(erlang, "Elixir.Agent", "get")
fn agent_get(agent: process.Pid, get_fun: fn(a) -> b) -> b

@external(erlang, "Elixir.Agent", "update")
fn agent_update(agent: process.Pid, update_fun: fn(a) -> a) -> atom.Atom

@external(erlang, "Elixir.Agent", "stop")
fn agent_stop(agent: process.Pid) -> atom.Atom

@external(erlang, "gen_server", "call")
fn gen_server_call(
  pid: process.Pid,
  request: a,
  timeout: Int,
) -> Result(b, atom.Atom)

@external(erlang, "gen_server", "cast")
fn gen_server_cast(pid: process.Pid, request: a) -> atom.Atom

/// Start a GenServer using gen_server:start_link
pub fn start_link(
  module_name: String,
  args: a,
) -> Result(GenServer, GenServerError) {
  let module_atom = binary_to_atom(module_name)
  case gen_server_start_link(module_atom, args, []) {
    Ok(pid) -> Ok(GenServer(pid))
    Error(reason) -> Error(types.StartError(atom.to_string(reason)))
  }
}

/// Start a GenServer by calling Module.start/1 directly
pub fn start(module_name: String, args: a) -> Result(GenServer, GenServerError) {
  let module_atom = binary_to_atom(module_name)
  let start_atom = binary_to_atom("start")
  case erlang_apply(module_atom, start_atom, [args]) {
    Ok(pid) -> Ok(GenServer(pid))
    Error(reason) -> Error(types.StartError(atom.to_string(reason)))
  }
}

/// Send a synchronous call to the GenServer
pub fn call(
  server: GenServer,
  request: a,
  timeout: Int,
) -> Result(b, GenServerError) {
  let GenServer(pid) = server
  case gen_server_call(pid, request, timeout) {
    Ok(response) -> Ok(response)
    Error(reason) -> Error(types.CallError(atom.to_string(reason)))
  }
}

/// Send an asynchronous cast to the GenServer  
pub fn cast(server: GenServer, request: a) -> Result(Nil, GenServerError) {
  let GenServer(pid) = server
  let result = gen_server_cast(pid, request)
  case atom.to_string(result) == "ok" {
    True -> Ok(Nil)
    False -> Error(types.CastError(atom.to_string(result)))
  }
}

/// Send a raw message to the GenServer (bypasses gen_server protocol)
pub fn send_message(server: GenServer, message: a) -> Nil {
  let GenServer(pid) = server
  let _ = erlang_send(pid, message)
  Nil
}

/// Create an atom from a string
pub fn make_atom(name: String) -> atom.Atom {
  binary_to_atom(name)
}

/// Get the underlying PID from a GenServer
pub fn unwrap_pid(server: GenServer) -> process.Pid {
  let GenServer(pid) = server
  pid
}

/// Helper for creating tagged messages for handle_info callbacks
pub fn tagged_message(
  tag: String,
  from: process.Pid,
  content: a,
) -> #(atom.Atom, process.Pid, a) {
  let tag_atom = binary_to_atom(tag)
  #(tag_atom, from, content)
}

// Agent functions

/// Start an Agent with an initial value
pub fn agent_start(initial_fun: fn() -> a) -> Result(Agent, GenServerError) {
  case agent_start_link(initial_fun) {
    Ok(pid) -> Ok(Agent(pid))
    Error(reason) -> Error(types.StartError(atom.to_string(reason)))
  }
}

/// Get the current state of an Agent
pub fn agent_get_state(agent: Agent, get_fun: fn(a) -> b) -> b {
  let Agent(pid) = agent
  agent_get(pid, get_fun)
}

/// Update the state of an Agent
pub fn agent_update_state(
  agent: Agent,
  update_fun: fn(a) -> a,
) -> Result(Nil, GenServerError) {
  let Agent(pid) = agent
  let result = agent_update(pid, update_fun)
  case atom.to_string(result) == "ok" {
    True -> Ok(Nil)
    False -> Error(types.CastError(atom.to_string(result)))
  }
}

/// Stop an Agent
pub fn agent_stop_process(agent: Agent) -> Result(Nil, GenServerError) {
  let Agent(pid) = agent
  let result = agent_stop(pid)
  case atom.to_string(result) == "ok" {
    True -> Ok(Nil)
    False -> Error(types.CastError(atom.to_string(result)))
  }
}

/// Get the underlying PID from an Agent
pub fn agent_unwrap_pid(agent: Agent) -> process.Pid {
  let Agent(pid) = agent
  pid
}
