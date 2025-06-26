//// Type-safe GenServer interop for Gleam
//// 
//// This module provides a safe interface to Elixir GenServers from Gleam.

import gleam/dynamic.{type Dynamic}
import gleam/erlang/atom.{type Atom}
import gleam/erlang/process.{type Pid}
import gleam/option.{type Option, None, Some}
import gleam/result
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
    "🎯 Final module name for atom creation: '" <> final_module_name <> "'",
  )
  let module_atom = binary_to_atom(final_module_name)
  logging.log(logging.Debug, "🔧 Created atom: " <> string.inspect(module_atom))

  logging.log(
    logging.Debug,
    "🚀 Calling gen_server:start_link with args: " <> string.inspect(args),
  )

  case gen_server_start_link(module_atom, args, []) {
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
    "🎯 Final module name for atom creation: '" <> final_module_name <> "'",
  )
  let module_atom = binary_to_atom(final_module_name)
  logging.log(
    logging.Debug,
    "🔧 Created module atom: " <> string.inspect(module_atom),
  )

  let name_atom = binary_to_atom(name)
  logging.log(
    logging.Debug,
    "🏷️ Created name atom: " <> string.inspect(name_atom),
  )

  let options = [dynamic.from(#(atom.create("name"), name_atom))]
  logging.log(logging.Debug, "⚙️ GenServer options: " <> string.inspect(options))

  logging.log(
    logging.Debug,
    "🚀 Calling gen_server:start_link with args: " <> string.inspect(args),
  )

  case gen_server_start_link(module_atom, args, options) {
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
  logging.log(
    logging.Debug,
    "📞 GenServer.call with request: " <> string.inspect(request),
  )
  call_timeout(server, request, 5000)
}

/// Send a synchronous call with custom timeout
pub fn call_timeout(
  server: GenServer,
  request: a,
  timeout: Int,
) -> Result(b, GenServerError) {
  let GenServer(pid) = server
  logging.log(
    logging.Debug,
    "📞⏱️ GenServer.call_timeout to PID "
      <> string.inspect(pid)
      <> " with timeout "
      <> string.inspect(timeout),
  )
  logging.log(logging.Debug, "📞⏱️ Request: " <> string.inspect(request))

  let response = gen_server_call(pid, request, timeout)
  logging.log(
    logging.Debug,
    "📞✅ GenServer call response: " <> string.inspect(response),
  )

  // For now, we'll just return the response directly
  // Users can check for error patterns themselves
  Ok(unsafe_coerce(response))
}

/// Call a named GenServer
pub fn call_named(name: String, request: a) -> Result(b, GenServerError) {
  logging.log(
    logging.Debug,
    "📞🏷️ GenServer.call_named to '"
      <> name
      <> "' with request: "
      <> string.inspect(request),
  )

  case lookup_name(name) {
    Ok(server) -> {
      logging.log(logging.Debug, "📞🏷️✅ Found named GenServer, making call")
      call(server, request)
    }
    Error(e) -> {
      logging.log(
        logging.Error,
        "📞🏷️❌ Named GenServer lookup failed: " <> string.inspect(e),
      )
      Error(e)
    }
  }
}

/// Send an asynchronous cast to the GenServer
pub fn cast(server: GenServer, request: a) -> Result(Nil, GenServerError) {
  let GenServer(pid) = server
  logging.log(
    logging.Debug,
    "📨 GenServer.cast to PID "
      <> string.inspect(pid)
      <> " with request: "
      <> string.inspect(request),
  )

  let result = gen_server_cast(pid, request)
  logging.log(
    logging.Debug,
    "📨✅ GenServer cast result: " <> string.inspect(result),
  )

  case atom.to_string(result) {
    "ok" -> {
      logging.log(logging.Debug, "📨✅ Cast successful")
      Ok(Nil)
    }
    other -> {
      logging.log(logging.Error, "📨❌ Cast failed with: " <> other)
      Error(CastError(other))
    }
  }
}

/// Cast to a named GenServer
pub fn cast_named(name: String, request: a) -> Result(Nil, GenServerError) {
  logging.log(
    logging.Debug,
    "📨🏷️ GenServer.cast_named to '"
      <> name
      <> "' with request: "
      <> string.inspect(request),
  )

  case lookup_name(name) {
    Ok(server) -> {
      logging.log(logging.Debug, "📨🏷️✅ Found named GenServer, making cast")
      cast(server, request)
    }
    Error(e) -> {
      logging.log(
        logging.Error,
        "📨🏷️❌ Named GenServer lookup failed: " <> string.inspect(e),
      )
      Error(e)
    }
  }
}

/// Get the PID of a GenServer
pub fn pid(server: GenServer) -> Pid {
  let GenServer(p) = server
  logging.log(logging.Debug, "🆔 GenServer.pid returning: " <> string.inspect(p))
  p
}

/// Look up a GenServer by registered name
pub fn lookup_name(name: String) -> Result(GenServer, GenServerError) {
  logging.log(logging.Debug, "🔍 GenServer.lookup_name for: '" <> name <> "'")

  let name_atom = binary_to_atom(name)
  logging.log(
    logging.Debug,
    "🔍 Created lookup atom: " <> string.inspect(name_atom),
  )

  let pid_result = erlang_whereis(name_atom)
  logging.log(logging.Debug, "🔍 whereis result: " <> string.inspect(pid_result))

  case dynamic.classify(pid_result) {
    "Pid" -> {
      logging.log(logging.Info, "🔍✅ Found GenServer PID for '" <> name <> "'")
      Ok(GenServer(unsafe_coerce(pid_result)))
    }
    "Atom" -> {
      logging.log(
        logging.Warning,
        "🔍❌ GenServer '" <> name <> "' returned atom (likely 'undefined')",
      )
      Error(NotFound(name))
    }
    other -> {
      logging.log(
        logging.Warning,
        "🔍❌ GenServer '" <> name <> "' not found, got type: " <> other,
      )
      Error(NotFound(name))
    }
  }
}

/// Stop a GenServer gracefully
pub fn stop(server: GenServer) -> Result(Nil, GenServerError) {
  logging.log(logging.Debug, "🛑 GenServer.stop called")
  cast(server, atom.create("stop"))
}
