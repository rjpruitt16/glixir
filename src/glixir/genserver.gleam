import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode.{type Decoder, run}
import gleam/erlang/atom.{type Atom}
import gleam/erlang/process.{type Pid}
import gleam/result
import gleam/string
import logging

pub opaque type GenServer(request, reply) {
  GenServer(pid: Pid)
}

pub type GenServerError {
  StartError(String)
  CallTimeout
  CallError(String)
  CastError(String)
  NotFound(String)
  DecodeError(List(decode.DecodeError))
}

// FFI functions
@external(erlang, "glixir_ffi", "start_genserver")
fn ffi_start_genserver(module: String, args: Dynamic) -> Result(Pid, Dynamic)

@external(erlang, "glixir_ffi", "start_genserver_named")
fn ffi_start_genserver_named(
  module: String,
  name: String,
  args: Dynamic,
) -> Result(Pid, Dynamic)

@external(erlang, "gen_server", "call")
fn gen_server_call(server: Pid, request: Dynamic, timeout: Int) -> Dynamic

@external(erlang, "gen_server", "cast")
fn gen_server_cast(server: Pid, request: Dynamic) -> Atom

@external(erlang, "erlang", "whereis")
fn erlang_whereis(name: Atom) -> Dynamic

@external(erlang, "gleam_stdlib", "identity")
fn unsafe_coerce(a: Dynamic) -> b

pub fn start_link(
  module: String,
  args: Dynamic,
) -> Result(GenServer(request, reply), GenServerError) {
  let final_module_name = case string.starts_with(module, "Elixir.") {
    True -> module
    False -> "Elixir." <> module
  }
  case ffi_start_genserver(final_module_name, args) {
    Ok(pid) -> Ok(GenServer(pid))
    Error(reason) -> Error(StartError(string.inspect(reason)))
  }
}

pub fn start_link_named(
  module: String,
  name: String,
  args: Dynamic,
) -> Result(GenServer(request, reply), GenServerError) {
  let final_module_name = case string.starts_with(module, "Elixir.") {
    True -> module
    False -> "Elixir." <> module
  }
  case ffi_start_genserver_named(final_module_name, name, args) {
    Ok(pid) -> Ok(GenServer(pid))
    Error(reason) -> Error(StartError(string.inspect(reason)))
  }
}

// Type-safe call: you must supply an encoder for requests and decoder for replies!
pub fn call(
  server: GenServer(request, reply),
  request: Dynamic,
  decoder: Decoder(reply),
) -> Result(reply, GenServerError) {
  call_timeout(server, request, 5000, decoder)
}

pub fn call_timeout(
  server: GenServer(request, reply),
  request: Dynamic,
  timeout: Int,
  decoder: Decoder(reply),
) -> Result(reply, GenServerError) {
  let GenServer(pid) = server
  let response = gen_server_call(pid, request, timeout)
  run(response, decoder)
  |> result.map_error(DecodeError)
}

pub fn call_named(
  name: Atom,
  request: Dynamic,
  decoder: Decoder(reply),
) -> Result(reply, GenServerError) {
  case lookup_name(name) {
    Ok(server) -> call(server, request, decoder)
    Error(e) -> Error(e)
  }
}

pub fn cast(
  server: GenServer(request, reply),
  request: Dynamic,
) -> Result(Nil, GenServerError) {
  let GenServer(pid) = server
  let result = gen_server_cast(pid, request)
  case atom.to_string(result) {
    "ok" -> Ok(Nil)
    other -> Error(CastError(other))
  }
}

pub fn cast_named(name: Atom, request: Dynamic) -> Result(Nil, GenServerError) {
  case lookup_name(name) {
    Ok(server) -> cast(server, request)
    Error(e) -> Error(e)
  }
}

pub fn lookup_name(
  name: Atom,
) -> Result(GenServer(request, reply), GenServerError) {
  let pid_result = erlang_whereis(name)
  case dynamic.classify(pid_result) {
    "Pid" -> Ok(GenServer(unsafe_coerce(pid_result)))
    _ -> Error(NotFound(atom.to_string(name)))
  }
}

pub fn stop(server: GenServer(request, reply)) -> Result(Nil, GenServerError) {
  Error(CastError("Use cast/call with explicit Atom message for stop"))
}

pub fn pid(server: GenServer(request, reply)) -> Pid {
  let GenServer(p) = server
  p
}
