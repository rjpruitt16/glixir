# genserver 🌟

[![Package Version](https://img.shields.io/hexpm/v/genserver)](https://hex.pm/packages/genserver)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/genserver/)
[![CI](https://github.com/rjpruitt16/genserver/workflows/test/badge.svg)](https://github.com/rjpruitt16/genserver/actions)

**Type-safe Elixir GenServer and Agent interop for Gleam**

Bridge the gap between Gleam's type safety and Elixir's battle-tested OTP. Call existing Elixir GenServers from Gleam with full type safety, or use Elixir Agents for simple state management.

## Why This Matters

- 🛡️ **Type Safety** - All GenServer operations are type-checked at compile time
- ⚡ **Zero Overhead** - Direct BEAM interop with no serialization
- 🏗️ **Production Ready** - Built on Elixir's 15+ years of OTP battle-testing  
- 🔄 **Gradual Migration** - Use existing Elixir services from new Gleam code
- 📦 **Simple API** - Ergonomic wrappers around complex OTP patterns

## Installation

```sh
gleam add genserver
```

## Quick Start

### Using Elixir Agents (Simple State Management)

```gleam
import genserver

pub fn main() {
  // Start an Agent with initial state
  let assert Ok(counter) = genserver.agent_start(fn() { 0 })
  
  // Update state safely
  let assert Ok(_) = genserver.agent_update(counter, fn(n) { n + 1 })
  
  // Get current state  
  let count = genserver.agent_get(counter, fn(n) { n })
  // count = 1
  
  // Clean up
  let assert Ok(_) = genserver.agent_stop(counter)
}
```

### Calling Existing Elixir GenServers

First, create an Elixir GenServer:

```elixir
# lib/my_server.ex
defmodule MyServer do
  use GenServer
  
  def start_link(initial_state) do
    GenServer.start_link(__MODULE__, initial_state)
  end
  
  def get_state(pid), do: GenServer.call(pid, :get_state)
  def increment(pid), do: GenServer.cast(pid, :increment)
  
  # Callbacks
  def init(state), do: {:ok, state}
  def handle_call(:get_state, _from, state), do: {:reply, state, state}
  def handle_cast(:increment, state), do: {:noreply, state + 1}
end
```

Then call it from Gleam:

```gleam
import genserver

pub fn use_elixir_genserver() {
  // Start the Elixir GenServer
  let assert Ok(server) = genserver.start_link("MyServer", 42)
  
  // Make type-safe calls
  let assert Ok(state) = genserver.call(server, genserver.atom("get_state"))
  // state = 42
  
  // Send async messages
  let assert Ok(_) = genserver.cast(server, genserver.atom("increment"))
  
  // Verify the change
  let assert Ok(new_state) = genserver.call(server, genserver.atom("get_state"))
  // new_state = 43
}
```

## Real-World Example: HTTP Client with Connection Pooling

```gleam
import genserver
import gleam/http/request
import gleam/http/response
import gleam/result

pub type ConnectionPool =
  genserver.Agent

pub fn create_pool(max_connections: Int) -> Result(ConnectionPool, _) {
  genserver.agent_start(fn() { 
    #(0, max_connections) // current, max
  })
}

pub fn get_connection(pool: ConnectionPool) -> Result(Bool, _) {
  genserver.agent_get(pool, fn(state) {
    let #(current, max) = state
    current < max
  })
}

pub fn checkout_connection(pool: ConnectionPool) -> Result(Nil, _) {
  genserver.agent_update(pool, fn(state) {
    let #(current, max) = state
    case current < max {
      True -> #(current + 1, max)
      False -> state
    }
  })
}

pub fn return_connection(pool: ConnectionPool) -> Result(Nil, _) {
  genserver.agent_update(pool, fn(state) {
    let #(current, max) = state
    #(int.max(0, current - 1), max)
  })
}
```

## API Overview

### GenServer Operations

- `start_link(module, args)` - Start a GenServer using OTP supervision
- `start(module, args)` - Start a GenServer directly  
- `call(server, request)` - Synchronous call with 5s timeout
- `call_timeout(server, request, ms)` - Synchronous call with custom timeout
- `cast(server, request)` - Asynchronous message
- `send_message(server, message)` - Raw message (triggers `handle_info`)

### Agent Operations  

- `agent_start(initial_fn)` - Start an Agent with initial state
- `agent_get(agent, get_fn)` - Get state (can transform)
- `agent_update(agent, update_fn)` - Update state
- `agent_stop(agent)` - Stop the Agent

### Utilities

- `atom(name)` - Create atoms for Elixir interop
- `tagged_message(tag, from, content)` - Create tagged tuples
- `pid(server)` - Extract raw PID for advanced operations

## Error Handling

All operations return `Result(T, GenServerError)` for safe error handling:

```gleam
import genserver

case genserver.call_timeout(server, "slow_op", 1000) {
  Ok(result) -> handle_success(result)
  Error(genserver.CallTimeout) -> handle_timeout()
  Error(genserver.CallError(reason)) -> handle_error(reason)
  Error(genserver.StartError(reason)) -> handle_start_failure(reason)
}
```

## Use Cases

- **🔄 Gradual Migration** - Call existing Elixir services from new Gleam code
- **📊 State Management** - Use Agents for simple, concurrent state  
- **🌐 HTTP Clients** - Connection pooling with type-safe operations
- **⚡ Real-time Systems** - Type-safe message passing between processes
- **🔌 External APIs** - Wrap Elixir GenServers with Gleam type safety
- **📈 Monitoring** - Collect metrics using battle-tested OTP patterns

## Comparison with Pure Gleam OTP

| Feature | This Library | Pure Gleam OTP |
|---------|-------------|----------------|  
| **Maturity** | 15+ years (Elixir) | New, evolving |
| **Type Safety** | ✅ Full | ✅ Full |
| **Performance** | ✅ Zero overhead | ✅ Zero overhead |
| **Ecosystem** | ✅ Huge Elixir ecosystem | 🔄 Growing |
| **Learning Curve** | 📖 Familiar to Elixir devs | 📖 New patterns |

## Contributing

Contributions welcome! This library bridges an important gap in the BEAM ecosystem.

```sh
git clone https://github.com/rjpruitt16/genserver
cd genserver
gleam test
```

## License

MIT - Build awesome things! 🚀``
