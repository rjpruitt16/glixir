/// Easy interop with Elixir GenServers from Gleam
/// 
/// This library provides a type-safe, ergonomic API for calling Elixir
/// GenServers from Gleam code running on the BEAM VM.
import genserver/internal
import genserver/types.{type Agent, type GenServer, type GenServerError}
import gleam/erlang/atom
import gleam/erlang/process

/// Start a GenServer using Module.start_link/1
/// 
/// This follows the OTP convention and will start the GenServer under
/// a supervisor if called from a supervision tree.
/// 
/// ## Example
/// 
/// ```gleam
/// let assert Ok(server) = start_link("MyServer", "initial_state")
/// ```
pub fn start_link(module: String, args: a) -> Result(GenServer, GenServerError) {
  internal.start_link("Elixir." <> module, args)
}

/// Start a GenServer using Module.start/1 (returns PID directly)
/// 
/// This calls the module's start/1 function directly, which should
/// return a PID. Use this when your Elixir GenServer has a custom
/// start function.
/// 
/// ## Example
/// 
/// ```gleam
/// let assert Ok(server) = start("MyServer", "initial_state")
/// ```
pub fn start(module: String, args: a) -> Result(GenServer, GenServerError) {
  internal.start("Elixir." <> module, args)
}

/// Send a synchronous call to the GenServer with default 5s timeout
/// 
/// This is equivalent to `gen_server:call/2` in Erlang/Elixir.
/// The GenServer's `handle_call/3` callback will be invoked.
/// 
/// ## Example
/// 
/// ```gleam
/// let assert Ok(response) = call(server, "get_state")
/// ```
pub fn call(server: GenServer, request: a) -> Result(b, GenServerError) {
  internal.call(server, request, 5000)
}

/// Send a synchronous call to the GenServer with custom timeout
/// 
/// ## Example
/// 
/// ```gleam
/// let assert Ok(response) = call_timeout(server, "slow_operation", 10000)
/// ```
pub fn call_timeout(
  server: GenServer,
  request: a,
  timeout: Int,
) -> Result(b, GenServerError) {
  internal.call(server, request, timeout)
}

/// Send an asynchronous cast to the GenServer
/// 
/// This is equivalent to `gen_server:cast/2` in Erlang/Elixir.
/// The GenServer's `handle_cast/2` callback will be invoked.
/// 
/// ## Example
/// 
/// ```gleam
/// let assert Ok(_) = cast(server, #("update_state", "new_value"))
/// ```
pub fn cast(server: GenServer, request: a) -> Result(Nil, GenServerError) {
  internal.cast(server, request)
}

/// Send a raw message to the GenServer (bypasses GenServer protocol)
/// 
/// This sends a message directly to the process, which will be handled
/// by the GenServer's `handle_info/2` callback. Useful for custom protocols.
/// 
/// ## Example
/// 
/// ```gleam
/// let my_pid = process.self()
/// let message = tagged_message("custom_event", my_pid, "some_data")
/// send_message(server, message)
/// ```
pub fn send_message(server: GenServer, message: a) -> Nil {
  internal.send_message(server, message)
}

/// Create a tagged message tuple for handle_info callbacks
/// 
/// This creates a tuple in the format `{tag, from_pid, content}` which
/// is a common pattern for custom messages in Elixir GenServers.
/// 
/// ## Example
/// 
/// ```gleam
/// let message = tagged_message("gleam_msg", process.self(), "Hello!")
/// // Creates: {:gleam_msg, #PID<...>, "Hello!"}
/// ```
pub fn tagged_message(
  tag: String,
  from: process.Pid,
  content: a,
) -> #(atom.Atom, process.Pid, a) {
  internal.tagged_message(tag, from, content)
}

/// Get the underlying PID from a GenServer
/// 
/// Use this when you need the raw PID for advanced operations.
/// 
/// ## Example
/// 
/// ```gleam
/// let server_pid = pid(server)
/// ```
pub fn pid(server: GenServer) -> process.Pid {
  internal.unwrap_pid(server)
}

/// Create an atom from a string
/// 
/// Useful for creating atoms to use in messages or function calls.
/// 
/// ## Example
/// 
/// ```gleam
/// let ok_atom = atom("ok")
/// ```
pub fn atom(name: String) -> atom.Atom {
  internal.make_atom(name)
}

// Agent functions

/// Start an Agent with an initial value function
/// 
/// Agents are simple wrappers around GenServers for managing state.
/// 
/// ## Example
/// 
/// ```gleam
/// let assert Ok(agent) = agent_start(fn() { 0 })
/// ```
pub fn agent_start(initial_fun: fn() -> a) -> Result(Agent, GenServerError) {
  internal.agent_start(initial_fun)
}

/// Get the current state from an Agent
/// 
/// ## Example
/// 
/// ```gleam
/// let value = agent_get(agent, fn(state) { state })
/// ```
pub fn agent_get(agent: Agent, get_fun: fn(a) -> b) -> b {
  internal.agent_get_state(agent, get_fun)
}

/// Update the state of an Agent
/// 
/// ## Example
/// 
/// ```gleam
/// let assert Ok(_) = agent_update(agent, fn(state) { state + 1 })
/// ```
pub fn agent_update(
  agent: Agent,
  update_fun: fn(a) -> a,
) -> Result(Nil, GenServerError) {
  internal.agent_update_state(agent, update_fun)
}

/// Stop an Agent
/// 
/// ## Example
/// 
/// ```gleam
/// let assert Ok(_) = agent_stop(agent)
/// ```
pub fn agent_stop(agent: Agent) -> Result(Nil, GenServerError) {
  internal.agent_stop_process(agent)
}

/// Get the underlying PID from an Agent
/// 
/// ## Example
/// 
/// ```gleam
/// let agent_pid = agent_pid(agent)
/// ```
pub fn agent_pid(agent: Agent) -> process.Pid {
  internal.agent_unwrap_pid(agent)
}
