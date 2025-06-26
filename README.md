# glixir 🌟

[![Package Version](https://img.shields.io/hexpm/v/glixir)](https://hex.pm/packages/glixir)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/glixir/)

**Seamless OTP interop between Gleam and Elixir/Erlang**

Bridge the gap between Gleam's type safety and the battle-tested OTP ecosystem. Use GenServers, Supervisors, Agents, and more from Gleam with confidence.

## Features

- ✅ **GenServer** - Type-safe calls to Elixir GenServers
- ✅ **DynamicSupervisor** - Runtime process supervision and management
- ✅ **Agent** - Simple state management with async operations
- 🚧 **Registry** - Process registration and discovery _(coming soon)_
- 🚧 **Task** - Async task execution _(coming soon)_
- 🚧 **Phoenix.PubSub** - Distributed messaging _(coming soon)_
- ✅ **Zero overhead** - Direct BEAM interop with clean Elixir helpers
- ✅ **Gradual adoption** - Use alongside existing Elixir code

## Installation

```sh
gleam add glixir
```

Add the Elixir helper module to your project:

```elixir
# lib/glixir_supervisor.ex
# Copy the Glixir.Supervisor module from the docs
```

## Quick Start

### DynamicSupervisor

```gleam
import glixir

pub fn main() {
  // Start a named dynamic supervisor
  let assert Ok(supervisor) = glixir.start_supervisor_named("my_supervisor", [])
  
  // Create a child specification
  let worker_spec = glixir.child_spec(
    id: "worker_1",
    module: "MyApp.Worker",
    function: "start_link", 
    args: [dynamic.string("config")]
  )
  
  // Start a child process
  case glixir.start_child(supervisor, worker_spec) {
    Ok(pid) -> io.println("Worker started!")
    Error(reason) -> io.println("Failed to start worker: " <> reason)
  }
  
  // List all children
  let children = glixir.which_children(supervisor)
  io.debug(children)
  
  // Get child counts
  let counts = glixir.count_children(supervisor)
  io.debug(counts)
}
```

### GenServer Interop

```gleam
import glixir

pub fn main() {
  // Start an Elixir GenServer from Gleam
  let assert Ok(server) = glixir.start_genserver("MyApp.Counter", dynamic.int(0))
  
  // Type-safe calls with custom decoders
  let assert Ok(count) = glixir.call_genserver(server, dynamic.string("get"), decode.int)
  io.debug(count)  // 0
  
  // Cast messages (fire and forget)
  let assert Ok(_) = glixir.cast_genserver(server, dynamic.string("increment"))
  
  // Call again to see the change
  let assert Ok(count) = glixir.call_genserver(server, dynamic.string("get"), decode.int)
  io.debug(count)  // 1
  
  // Stop the GenServer
  let assert Ok(_) = glixir.stop_genserver(server)
}
```

### Agent State Management

```gleam
import glixir
import gleam/dynamic/decode

pub fn main() {
  // Start an agent with initial state
  let assert Ok(counter) = glixir.start_agent(fn() { 42 })
  
  // Get state with a decoder
  let assert Ok(value) = glixir.get_agent(counter, fn(x) { x }, decode.int)
  io.debug(value)  // 42
  
  // Update state
  let assert Ok(_) = glixir.update_agent(counter, fn(n) { n + 10 })
  
  // Get and update in one operation
  let assert Ok(old_value) = glixir.get_and_update_agent(
    counter, 
    fn(n) { #(n, n * 2) },
    decode.int
  )
  io.debug(old_value)  // 52
  
  // Stop the agent
  let assert Ok(_) = glixir.stop_agent(counter)
}
```

## Working with Elixir Modules

### Creating an Elixir Worker

```elixir
# lib/my_app/worker.ex
defmodule MyApp.Worker do
  use GenServer
  
  def start_link(config) do
    GenServer.start_link(__MODULE__, config)
  end
  
  def init(config) do
    {:ok, %{config: config, count: 0}}
  end
  
  def handle_call(:get_count, _from, state) do
    {:reply, state.count, state}
  end
  
  def handle_cast(:increment, state) do
    {:noreply, %{state | count: state.count + 1}}
  end
end
```

### Using from Gleam

```gleam
import glixir
import gleam/dynamic
import gleam/dynamic/decode

pub fn worker_example() {
  // Start the supervisor
  let assert Ok(sup) = glixir.start_supervisor_named("worker_supervisor", [])
  
  // Create worker specification  
  let worker_spec = glixir.child_spec(
    id: "my_worker",
    module: "MyApp.Worker",
    function: "start_link",
    args: [dynamic.string("some_config")]
  )
  
  // Start the worker under supervision
  let assert Ok(worker_pid) = glixir.start_child(sup, worker_spec)
  
  // Interact with the worker using GenServer calls
  let assert Ok(count) = glixir.call_genserver(
    worker_pid, 
    dynamic.atom("get_count"), 
    decode.int
  )
  io.debug(count)  // 0
  
  // Send a cast message
  let assert Ok(_) = glixir.cast_genserver(worker_pid, dynamic.atom("increment"))
  
  // Check the count again
  let assert Ok(count) = glixir.call_genserver(
    worker_pid, 
    dynamic.atom("get_count"), 
    decode.int
  )
  io.debug(count)  // 1
}
```

## Advanced Patterns

### Worker Pool Pattern

```gleam
import glixir
import gleam/list
import gleam/int

pub fn start_worker_pool(pool_size: Int) {
  let assert Ok(supervisor) = glixir.start_supervisor_named("worker_pool", [])
  
  // Start multiple workers
  list.range(1, pool_size)
  |> list.map(fn(i) {
    let worker_spec = glixir.child_spec(
      id: "worker_" <> int.to_string(i),
      module: "MyApp.PoolWorker", 
      function: "start_link",
      args: [dynamic.int(i)]
    )
    
    glixir.start_child(supervisor, worker_spec)
  })
  |> list.all(fn(result) {
    case result {
      Ok(_) -> True
      Error(_) -> False
    }
  })
}
```

### Fault-Tolerant Services

```gleam
import glixir

pub fn start_resilient_service() {
  let assert Ok(supervisor) = glixir.start_supervisor_named("app_supervisor", [])
  
  // Start critical services with permanent restart
  let cache_spec = glixir.worker_spec("cache", "MyApp.Cache", [])
  let database_spec = glixir.worker_spec("database", "MyApp.Database", [])
  
  // Start optional services with temporary restart
  let metrics_spec = glixir.SimpleChildSpec(
    ..glixir.worker_spec("metrics", "MyApp.Metrics", []),
    restart: glixir.temporary
  )
  
  let assert Ok(_) = glixir.start_child(supervisor, cache_spec)
  let assert Ok(_) = glixir.start_child(supervisor, database_spec)
  let assert Ok(_) = glixir.start_child(supervisor, metrics_spec)
  
  supervisor
}
```

## Configuration

### Restart Strategies

```gleam
import glixir

// Permanent: Always restart (default)
let permanent_worker = glixir.SimpleChildSpec(
  ..glixir.worker_spec("critical", "MyApp.Critical", []),
  restart: glixir.permanent
)

// Temporary: Never restart
let temporary_worker = glixir.SimpleChildSpec(
  ..glixir.worker_spec("temp", "MyApp.TempWorker", []),
  restart: glixir.temporary
)

// Transient: Restart only on abnormal termination
let transient_worker = glixir.SimpleChildSpec(
  ..glixir.worker_spec("transient", "MyApp.Transient", []),
  restart: glixir.transient
)
```

### Custom Timeouts

```gleam
import glixir

let custom_spec = glixir.SimpleChildSpec(
  ..glixir.worker_spec("custom", "MyApp.Custom", []),
  shutdown_timeout: 10000,  // 10 seconds to shutdown gracefully
  restart: glixir.permanent
)
```

## Type Safety Notes

While this library provides type-safe wrappers on the Gleam side, remember:

1. **Runtime Types**: Elixir/Erlang processes are dynamically typed at runtime
2. **Message Contracts**: Ensure message formats match between Gleam and Elixir
3. **Decoder Functions**: Always provide appropriate decoders for return values
4. **Error Handling**: Handle all potential decode and process errors
5. **Testing**: Test integration points thoroughly

## Error Handling

```gleam
import glixir

pub fn robust_worker_start() {
  case glixir.start_supervisor_named("robust_sup", []) {
    Ok(supervisor) -> {
      let spec = glixir.worker_spec("worker", "MyApp.Worker", [])
      
      case glixir.start_child(supervisor, spec) {
        Ok(pid) -> {
          io.println("Worker started successfully")
          Ok(#(supervisor, pid))
        }
        Error(reason) -> {
          io.println("Failed to start worker: " <> reason)
          Error("worker_start_failed")
        }
      }
    }
    Error(_supervisor_error) -> {
      io.println("Failed to start supervisor")
      Error("supervisor_start_failed")
    }
  }
}
```

## About the Author

Built by **Rahmi Pruitt** - Ex-Twitch/Amazon Engineer turned indie hacker, on a mission to bring Gleam to the mainstream! 🚀

I believe Gleam's type safety + Elixir's battle-tested OTP = the future of fault-tolerant systems. This library bridges that gap, making OTP's superpowers accessible to Gleam developers.

**Connect with me:**
- 💼 [LinkedIn](https://www.linkedin.com/in/rahmi-pruitt-a1bb4a127/)
- 🐦 Follow my Gleam journey and indie hacking adventures

*"Making concurrent programming delightful, one type at a time."*
