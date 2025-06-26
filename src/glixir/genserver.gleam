//// Type-safe GenServer interop for Gleam
//// 
//// This module provides a safe interface to Elixir GenServers from Gleam.

import gleam/dynamic.{type Dynamic}
import gleam/erlang/atom.{type Atom}
import gleam/erlang/process.{type Pid}
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string

/// Opaque type representing a GenServer process
pub opaque type GenServer {
  GenServer(pid: Pid)
}

/// Errors that can occur in GenServer operations
pub type GenServerError {
  StartError(reason: String)
  CallTimeout
  CallError(reason: String)
  CastError(reason: String)
  NotFound(name: String)
}

// FFI functions
@external(erlang, "gen_server", "start_link")
fn gen_server_start_link(
  module: Atom,
  args: a,
  options: List(Dynamic),
) -> Result(Pid, Dynamic)

@external(erlang, "gen_server", "call")
fn gen_server_call(server: Pid, request: a, timeout: Int) -> Dynamic

@external(erlang, "gen_server", "cast")
fn gen_server_cast(server: Pid, request: a) -> Atom

@external(erlang, "erlang", "whereis")
fn erlang_whereis(name: Atom) -> Dynamic

@external(erlang, "erlang", "binary_to_atom")
fn binary_to_atom(name: String) -> Atom

// Helper to unsafely coerce dynamic to any type
@external(erlang, "gleam_stdlib", "identity")
fn unsafe_coerce(a: Dynamic) -> b

/// Start a GenServer using Module.start_link/1
pub fn start_link(module: String, args: a) -> Result(GenServer, GenServerError) {
  let module_atom = binary_to_atom("Elixir." <> module)

  case gen_server_start_link(module_atom, args, []) {
    Ok(pid) -> Ok(GenServer(pid))
    Error(reason) -> Error(StartError(string.inspect(reason)))
  }
}

/// Start a GenServer with a registered name
pub fn start_link_named(
  module: String,
  name: String,
  args: a,
) -> Result(GenServer, GenServerError) {
  let module_atom = binary_to_atom("Elixir." <> module)
  let name_atom = binary_to_atom(name)
  let options = [dynamic.from(#(atom.create("name"), name_atom))]

  case gen_server_start_link(module_atom, args, options) {
    Ok(pid) -> Ok(GenServer(pid))
    Error(reason) -> Error(StartError(string.inspect(reason)))
  }
}

/// Send a synchronous call to the GenServer (5s timeout)
pub fn call(server: GenServer, request: a) -> Result(b, GenServerError) {
  call_timeout(server, request, 5000)
}

/// Send a synchronous call with custom timeout
pub fn call_timeout(
  server: GenServer,
  request: a,
  timeout: Int,
) -> Result(b, GenServerError) {
  let GenServer(pid) = server
  let response = gen_server_call(pid, request, timeout)

  // For now, we'll just return the response directly
  // Users can check for error patterns themselves
  Ok(unsafe_coerce(response))
}

/// Call a named GenServer
pub fn call_named(name: String, request: a) -> Result(b, GenServerError) {
  case lookup_name(name) {
    Ok(server) -> call(server, request)
    Error(e) -> Error(e)
  }
}

/// Send an asynchronous cast to the GenServer
pub fn cast(server: GenServer, request: a) -> Result(Nil, GenServerError) {
  let GenServer(pid) = server
  let result = gen_server_cast(pid, request)

  case atom.to_string(result) {
    "ok" -> Ok(Nil)
    other -> Error(CastError(other))
  }
}

/// Cast to a named GenServer
pub fn cast_named(name: String, request: a) -> Result(Nil, GenServerError) {
  case lookup_name(name) {
    Ok(server) -> cast(server, request)
    Error(e) -> Error(e)
  }
}

/// Get the PID of a GenServer
pub fn pid(server: GenServer) -> Pid {
  let GenServer(p) = server
  p
}

/// Look up a GenServer by registered name
pub fn lookup_name(name: String) -> Result(GenServer, GenServerError) {
  let name_atom = binary_to_atom(name)
  let pid_result = erlang_whereis(name_atom)

  case dynamic.classify(pid_result) {
    "Pid" -> Ok(GenServer(unsafe_coerce(pid_result)))
    "Atom" -> Error(NotFound(name))
    // Likely 'undefined'
    _ -> Error(NotFound(name))
  }
}

/// Stop a GenServer gracefully
pub fn stop(server: GenServer) -> Result(Nil, GenServerError) {
  cast(server, atom.create("stop"))
}
