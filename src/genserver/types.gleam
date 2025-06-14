import gleam/erlang/process
import gleam/option.{type Option}

/// Opaque type wrapping a GenServer PID for type safety
pub type GenServer {
  GenServer(pid: process.Pid)
}

/// Opaque type wrapping an Agent PID for type safety  
pub type Agent {
  Agent(pid: process.Pid)
}

/// Errors that can occur in GenServer operations
pub type GenServerError {
  StartError(reason: String)
  CallTimeout
  CallError(reason: String)
  CastError(reason: String)
  InvalidModule(module: String)
}

/// Options for starting GenServers
pub type StartOptions {
  StartOptions(name: Option(String), timeout: Option(Int), debug: List(String))
}
