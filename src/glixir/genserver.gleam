//// Type-safe GenServer interop for Gleam
//// 
//// This module provides a safe interface to Elixir GenServers from Gleam.

import gleam/dynamic.{type Dynamic}
import gleam/erlang/atom.{type Atom}
import gleam/erlang/process.{type Pid}
import gleam/string
import logging

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

// FFI functions - Using our custom FFI for reliable operation
@external(erlang, "glixir_ffi", "start_genserver")
fn ffi_start_genserver(module: String, args: a) -> Result(Pid, Dynamic)

@external(erlang, "glixir_ffi", "start_genserver_named")
fn ffi_start_genserver_named(
  module: String,
  name: String,
  args: a,
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
  logging.log(
    logging.Debug,
    "🔍 GenServer.start_link called with module: '" <> module <> "'",
  )

  let final_module_name = case string.starts_with(module, "Elixir.") {
    True -> {
      logging.log(
        logging.Debug,
        "✅ Module already has Elixir. prefix: " <> module,
      )
      module
    }
    False -> {
      let prefixed = "Elixir." <> module
      logging.log(
        logging.Debug,
        "➕ Adding Elixir. prefix: " <> module <> " → " <> prefixed,
      )
      prefixed
    }
  }

  logging.log(
    logging.Debug,
    "🚀 Calling FFI start_genserver with module: " <> final_module_name,
  )

  case ffi_start_genserver(final_module_name, args) {
    Ok(pid) -> {
      logging.log(
        logging.Info,
        "✅ GenServer started successfully: " <> string.inspect(pid),
      )
      Ok(GenServer(pid))
    }
    Error(reason) -> {
      logging.log(
        logging.Error,
        "❌ GenServer start failed: " <> string.inspect(reason),
      )
      Error(StartError(string.inspect(reason)))
    }
  }
}

/// Start a GenServer with a registered name
pub fn start_link_named(
  module: String,
  name: String,
  args: a,
) -> Result(GenServer, GenServerError) {
  logging.log(
    logging.Debug,
    "🔍 GenServer.start_link_named called with module: '"
      <> module
      <> "', name: '"
      <> name
      <> "'",
  )

  let final_module_name = case string.starts_with(module, "Elixir.") {
    True -> {
      logging.log(
        logging.Debug,
        "✅ Module already has Elixir. prefix: " <> module,
      )
      module
    }
    False -> {
      let prefixed = "Elixir." <> module
      logging.log(
        logging.Debug,
        "➕ Adding Elixir. prefix: " <> module <> " → " <> prefixed,
      )
      prefixed
    }
  }

  logging.log(
    logging.Debug,
    "🚀 Calling FFI start_genserver_named with module: "
      <> final_module_name
      <> ", name: "
      <> name,
  )

  case ffi_start_genserver_named(final_module_name, name, args) {
    Ok(pid) -> {
      logging.log(
        logging.Info,
        "✅ Named GenServer '"
          <> name
          <> "' started successfully: "
          <> string.inspect(pid),
      )
      Ok(GenServer(pid))
    }
    Error(reason) -> {
      logging.log(
        logging.Error,
        "❌ Named GenServer '"
          <> name
          <> "' start failed: "
          <> string.inspect(reason),
      )
      Error(StartError(string.inspect(reason)))
    }
  }
}

/// Send a synchronous call to the GenServer (5s timeout)
pub fn call(server: GenServer, request: a) -> Result(b, GenServerError) {
  // No atom.create here: request must be constructed by caller, e.g. atom, tuple, int, etc.
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
  Ok(unsafe_coerce(response))
}

/// Call a named GenServer (now requires Atom name)
pub fn call_named(name: Atom, request: a) -> Result(b, GenServerError) {
  case lookup_name(name) {
    Ok(server) -> call(server, request)
    Error(e) -> Error(e)
  }
}

/// Cast (fire and forget)
pub fn cast(server: GenServer, request: a) -> Result(Nil, GenServerError) {
  let GenServer(pid) = server
  let result = gen_server_cast(pid, request)
  case atom.to_string(result) {
    "ok" -> Ok(Nil)
    other -> Error(CastError(other))
  }
}

/// Cast to a named GenServer (explicit Atom name)
pub fn cast_named(name: Atom, request: a) -> Result(Nil, GenServerError) {
  case lookup_name(name) {
    Ok(server) -> cast(server, request)
    Error(e) -> Error(e)
  }
}

/// Look up a GenServer by registered Atom name
pub fn lookup_name(name: Atom) -> Result(GenServer, GenServerError) {
  let pid_result = erlang_whereis(name)
  case dynamic.classify(pid_result) {
    "Pid" -> Ok(GenServer(unsafe_coerce(pid_result)))
    _ -> Error(NotFound(atom.to_string(name)))
  }
}

/// Stop a GenServer gracefully (you now call cast or cast_named with atom)
pub fn stop(server: GenServer) -> Result(Nil, GenServerError) {
  // Caller must do: genserver.cast(server, atom)
  Error(CastError("Use cast with explicit Atom message for stop"))
}

/// Get the PID of a GenServer
pub fn pid(server: GenServer) -> Pid {
  let GenServer(p) = server
  p
}
