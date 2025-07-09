# glixir 🌟

[![Package Version](https://img.shields.io/hexpm/v/glixir)](https://hex.pm/packages/glixir)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/glixir/)

**Seamless OTP interop between Gleam and Elixir/Erlang**

Bridge the gap between Gleam's type safety and the battle-tested OTP ecosystem. Use GenServers, Supervisors, Agents, Registry, and more from Gleam with confidence.

## Features

- ✅ **GenServer** - Type-safe calls to Elixir GenServers
- ✅ **DynamicSupervisor** - Runtime process supervision and management
- ✅ **Agent** - Simple state management with async operations
- ✅ **Registry** - Dynamic process registration and Subject lookup
- 🚧 **Task** - Async task execution _(coming soon)_
- ✅ **Phoenix.PubSub** - Distributed messaging and event broadcasting
- ✅ **Zero overhead** - Direct BEAM interop with clean Elixir helpers
- ✅ **Gradual adoption** - Use alongside existing Elixir code

---

## Type Safety & Phantom Types

> **A note from your neighborhood type enthusiast:**

Some `glixir` APIs (notably process calls, GenServer, Agent, Registry) still require passing `Dynamic` values—this is the price of seamless BEAM interop and runtime dynamism. While decoders on return values help catch mismatches, full compile-time type safety isn’t always possible... **yet**.

But here’s the good news:
We’re actively rolling out [phantom types](https://gleam.run/tour/phantom_types/) across the API, banishing `Dynamic` wherever possible and making misused actors a compile-time relic.

---

### Type safety level
```
GenServer:     [■■■■■■□□□□] 60% - Explicit atom/msg boundary, type wrappers for all ops. Dynamic still leaks on BEAM interop.
Supervisor:    [■■■■■■■■□□] 80% - Child specs are typed, but args are Dynamic.
Registry:      [■■■■■□□□□□] 50% - Keyed by String, subject is phantom-typed, messages aren’t.
Agent:         [■■■■■■■■■■] 100% - State and API fully phantom-typed. Only decode errors left.
PubSub:        [■■■■■□□□□□] 50% - Topics/IDs typed, but payloads Dynamic.
Task:          [□□□□□□□□□□] 0% - Not started.
```

> *Full green bars are the dream; until then, decoders are your seatbelt!*

---

## Why Not 100% Type-Safe Now?

Blame Erlang! (Just kidding, blame dynamic process boundaries.)
You get strict safety *inside* Gleam, but as soon as you jump the BEAM-to-BEAM fence, the runtime is your playground. So, until Gleam’s type system can tame Elixir’s wild world, we work with decoders and are pushing hard to get you closer to total type bliss.

---

**Want to help speed this up? File issues, suggest API improvements, or just cheer us on in the repo!**

---

## ⚡ Atom Safety & Fail-Fast API

**glixir** now requires all process, registry, and module names to be existing atoms—typos or missing modules crash immediately with `{bad_atom, ...}`.

- Avoids BEAM atom leaks and silent bugs.
- If you typo or use a non-existent module, you’ll see a *loud* error.
- Pro-tip: Always reference the real module, or pre-load it in Elixir before calling from Gleam.

_This makes glixir safer by default—don’t trust user input as atom names!_

---

## Installation

```sh
gleam add glixir
```

Add the Elixir helper modules to your project:

```elixir
# lib/glixir_supervisor.ex and lib/glixir_registry.ex
# Copy the helper modules from the docs
```

## Quick Start
### PubSub - Distributed Messaging

**Perfect for real-time event broadcasting across your system! 📡**

```gleam
import glixir
import gleam/erlang/process

pub fn pubsub_example() {
  // Start a PubSub system
  let assert Ok(_pubsub) = glixir.start_pubsub("my_app_events")
  
  // Subscribe to events
  let assert Ok(_) = glixir.pubsub_subscribe("my_app_events", "user:123:metrics")
  
  // From anywhere in your system, broadcast events
  let metric_event = #("page_view", "user_123", 1.0)
  let assert Ok(_) = glixir.pubsub_broadcast(
    "my_app_events", 
    "user:123:metrics",
    metric_event
  )
  
  // Handle incoming messages in your actor
  case process.receive(subject, 100) {
    Ok(#("page_view", user_id, count)) -> {
      io.println("User " <> user_id <> " viewed " <> float.to_string(count) <> " pages")
    }
    Error(_) -> io.println("No messages")
  }
  
  // Cleanup when done
  let assert Ok(_) = glixir.pubsub_unsubscribe("my_app_events", "user:123:metrics")
}
```

### Registry - Dynamic Actor Discovery

**The game-changer for building scalable actor systems! 🎯**

```gleam
import glixir
import gleam/erlang/process

pub type UserMessage {
  RecordMetric(name: String, value: Float)
  GetStats
}

pub fn actor_discovery_example() {
  // Start registry for actor lookup
  let assert Ok(_registry) = glixir.start_registry("user_actors")
  
  // Start supervisor for dynamic actors
  let assert Ok(supervisor) = glixir.start_supervisor_simple()
  
  // Spawn a user actor dynamically
  let user_spec = glixir.child_spec(
    id: "user_123",
    module: "MyApp.UserActor", 
    function: "start_link",
    args: [dynamic.string("user_123")]
  )
  
  let assert Ok(user_pid) = glixir.start_child(supervisor, user_spec)
  
  // Actor registers itself in the registry
  let user_subject = process.new_subject()
  let assert Ok(_) = glixir.register_subject("user_actors", "user_123", user_subject)
  
  // Later... find and message the actor from anywhere!
  case glixir.lookup_subject("user_actors", "user_123") {
    Ok(subject) -> {
      process.send(subject, RecordMetric("page_views", 1.0))
      io.println("Metric sent to user actor! 📊")
    }
    Error(_) -> io.println("User actor not found")
  }
}
```

**Perfect for:**
- 🎯 **Metrics platforms** - Find user actors by ID
- 🎮 **Game servers** - Locate player sessions
- 💬 **Chat systems** - Route messages to user connections
- 📊 **Real-time dashboards** - Dynamic process coordination

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
import gleam/erlang/atom
import gleam/dynamic
import gleam/dynamic/decode

pub fn main() {
  // Start an Elixir GenServer from Gleam
  let assert Ok(server) = glixir.start_genserver("MyApp.Counter", dynamic.int(0))

  // Type-safe calls (no atom.create magic: you supply the atom/message!)
  let assert Ok(count) = glixir.call_genserver(server, atom.create("get_count"), decode.int)
  io.debug(count)  // 0

  // Cast messages (fire and forget, explicit atom!)
  let assert Ok(_) = glixir.cast_genserver(server, atom.create("increment"))

  // Call again to see the change
  let assert Ok(count) = glixir.call_genserver(server, atom.create("get_count"), decode.int)
  io.debug(count)  // 1

  // Stop the GenServer - just cast the stop atom yourself!
  let assert Ok(_) = glixir.cast_genserver(server, atom.create("stop"))
}
```


---

## Agent State Management

```gleam
import glixir
import gleam/dynamic/decode
import gleam/erlang/atom

pub fn main() {
  // Start an agent with initial state
  let assert Ok(counter) = glixir.start_agent(fn() { 42 })

  // Get state with a decoder (type safe)
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

  // Stop the agent with a reason (now explicit)
  let assert Ok(_) = glixir.stop_agent(counter, atom.create("normal"))
}
```

Let me know if you want the full Markdown for your README or just the “Agent”/type safety section. I can also generate a badge-style SVG or emoji progress meter if you want it looking real flashy.
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

### Scalable Actor System with Registry

```gleam
import glixir
import gleam/erlang/process
import gleam/dynamic

pub type MetricMessage {
  Record(name: String, value: Float, user_id: String)
  Subscribe(subject: process.Subject(String))
}

pub fn metrics_platform_example() {
  // Infrastructure setup
  let assert Ok(_) = glixir.start_registry("metric_actors")
  let assert Ok(_) = glixir.start_registry("user_sessions") 
  let assert Ok(supervisor) = glixir.start_supervisor_named("metrics_supervisor", [])
  
  // Spawn metric collector actor
  let metric_spec = glixir.child_spec(
    id: "metric_collector",
    module: "MyApp.MetricCollector",
    function: "start_link", 
    args: []
  )
  
  let assert Ok(_metric_pid) = glixir.start_child(supervisor, metric_spec)
  
  // When a user connects, spawn their personal actor
  let user_id = "user_12345"
  let user_spec = glixir.child_spec(
    id: user_id,
    module: "MyApp.UserActor",
    function: "start_link",
    args: [dynamic.string(user_id)]
  )
  
  let assert Ok(_user_pid) = glixir.start_child(supervisor, user_spec)
  
  // User actor registers itself
  let user_subject = process.new_subject()
  let assert Ok(_) = glixir.register_subject("user_sessions", user_id, user_subject)
  
  // From anywhere in the system - send metrics to user
  case glixir.lookup_subject("user_sessions", user_id) {
    Ok(subject) -> {
      process.send(subject, Record("page_view", 1.0, user_id))
      io.println("✅ Metric routed to user actor!")
    }
    Error(_) -> io.println("❌ User session not found")
  }
  
  // Cleanup when user disconnects
  let assert Ok(_) = glixir.unregister_subject("user_sessions", user_id)
  let assert Ok(_) = glixir.terminate_child(supervisor, user_id)
}
```

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

## Registry API Reference

```gleam
// Start a unique registry (most common)
let assert Ok(registry) = glixir.start_registry("my_processes")

// Register a Subject by key  
let subject = process.new_subject()
let assert Ok(_) = glixir.register_subject("my_processes", "worker_1", subject)

// Look up Subject by key
case glixir.lookup_subject("my_processes", "worker_1") {
  Ok(found_subject) -> process.send(found_subject, MyMessage)
  Error(glixir.NotFound) -> io.println("Process not found")
  Error(_) -> io.println("Registry error")
}

// Clean up
let assert Ok(_) = glixir.unregister_subject("my_processes", "worker_1")
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

## Real-World Use Cases

**TrackTags** - Auto-scaling metrics platform built with glixir:
- ✅ Dynamic user actors spawned per session
- ✅ Registry-based actor discovery by user ID  
- ✅ Real-time metric collection and coordination
- ✅ Fault-tolerant supervision trees

*"glixir made building a distributed metrics platform feel like writing normal Gleam code. The Registry system is a game-changer for actor coordination!"*

## About the Author

Built by **Rahmi Pruitt** - Ex-Twitch/Amazon Engineer turned indie hacker, on a mission to bring Gleam to the mainstream! 🚀

I believe Gleam's type safety + Elixir's battle-tested OTP = the future of fault-tolerant systems. This library bridges that gap, making OTP's superpowers accessible to Gleam developers.

**Connect with me:**
- 💼 [LinkedIn](https://www.linkedin.com/in/rahmi-pruitt-a1bb4a127/)
- 🐦 Follow my Gleam journey and indie hacking adventures

*"Making concurrent programming delightful, one type at a time."*

---

**⭐ Star this repo if glixir helped you build something awesome!** Your support helps bring mature OTP tooling to the Gleam ecosystem.
