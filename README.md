# Glixir 🌟

[![Package Version](https://img.shields.io/hexpm/v/glixir)](https://hex.pm/packages/glixir)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/glixir/)

**A Safe(ish) OTP interop between Gleam and Elixir/Erlang**

Bridge the gap between Gleam's type safety and the battle-tested OTP ecosystem. Use GenServers, Supervisors, Agents, Registry, and more from Gleam with confidence.

## Features

- ✅ **GenServer** - Type-safe calls to Elixir GenServers
- ✅ **DynamicSupervisor** - Runtime process supervision and management
- ✅ **Agent (now generic!)** - Type-safe state management with async operations
- ✅ **Registry** - Dynamic process registration and Subject lookup
- 🚧 **Task** - Async task execution _(coming soon)_
- ✅ **Phoenix.PubSub** - Distributed messaging with JSON-based type safety
- ✅ **Zero overhead** - Direct BEAM interop with clean Elixir helpers
- ✅ **Gradual adoption** - Use alongside existing Elixir code
- ✅ **syn** - Distributed process registry and PubSub coordination

---

## Type Safety & Phantom Types

> **A note from your neighborhood type enthusiast:**
>
> Some `glixir` APIs (notably process calls, GenServer, Registry) still require passing `Dynamic` values—this is the price of seamless BEAM interop and runtime dynamism. While decoders on return values help catch mismatches, full compile-time type safety isn't always possible... **yet**.
>
> But here's the good news:
> We're actively rolling out [phantom types](https://gleam.run/tour/phantom_types/) and generics across the API, banishing `Dynamic` wherever possible and making misused actors a compile-time relic.

---

### Type safety level
```
GenServer:     [■■■■■■■■□□] 80% - Request/reply types enforced by Gleam, decoder required, but runtime BEAM interop can still fail if types disagree.
Supervisor:    [■■■■■■■■■□] 90% - Phantom-typed with compile-time child spec validation, args/replies bounded by generics.
Registry:      [■■■■■■■■■□] 90% - Phantom-typed with compile-time key/message validation, requires key encoders.
Agent:         [■■■■■■■■■■] 100% - State and API fully generic and type safe!
PubSub:        [■■■■■■■■□□] 80% - JSON-based type safety with user-defined encoders/decoders. Phantom-typed for message_type.
syn:           [■■■■■■■■□□] 80% - Distributed coordination with type-safe message patterns, runtime node discovery.
Task:          [□□□□□□□□□□] 0% - Not started.
```

> *Full green bars are the dream; until then, decoders are your seatbelt!*

---

## Why Not 100% Type-Safe Now?

Blame Erlang! (Just kidding, blame dynamic process boundaries.)
You get strict safety *inside* Gleam, but as soon as you jump the BEAM-to-BEAM fence, the runtime is your playground. So, until Gleam's type system can tame Elixir's wild world, we work with decoders and are pushing hard to get you closer to total type bliss.

---

# ⚠️ Caveats: BEAM Interop Trade-offs

Glixir provides **bounded type safety** - the maximum safety possible while maintaining full OTP functionality. Some limitations are **inherent to BEAM interop**, not design flaws:

## The Safety Spectrum
- **Pure Gleam:** 100% compile-time safe, but no distributed features  
- **Glixir:** 70-90% compile-time safe + runtime validation, full OTP power  
- **Raw FFI:** ~20% safe, full OTP power, high risk

## Unavoidable BEAM Realities
- **Process discovery** - distributed systems have runtime process existence
- **Module loading** - OTP's dynamic nature requires string module names  
- **Cross-language boundaries** - serialization between Gleam and Elixir

## What You Get
✅ **Compile-time:** Prevents category errors, type mixing, wrong message types  
⚠️ **Runtime:** Process existence, module validity, message format compatibility  

**Bottom Line:** Glixir is the sweet spot - maximum practical safety with essential functionality that core Gleam simply doesn't provide.

**Want to help speed this up? File issues, suggest API improvements, or just cheer us on in the repo!**

---

## ⚡ Atom Safety & Fail-Fast API

**glixir** now requires all process, registry, and module names to be existing atoms—typos or missing modules crash immediately with `{bad_atom, ...}`.

- Avoids BEAM atom leaks and silent bugs.
- If you typo or use a non-existent module, you'll see a *loud* error.
- Pro-tip: Always reference the real module, or pre-load it in Elixir before calling from Gleam.

_This makes glixir safer by default—don't trust user input as atom names!_

---


### syn - Distributed Process Coordination

**Distributed service discovery and event streaming across BEAM nodes! 🌐**

Use Erlang's battle-tested `syn` library for distributed coordination, consensus algorithms, and fault-tolerant process management.

```gleam
import glixir/syn
import gleam/json

pub fn distributed_example() {
  // Initialize scopes at application startup
  syn.init_scopes(["worker_pools", "coordination"])
  
  // Register this process in a distributed pool
  let load_info = #(cpu_usage: 0.3, queue_size: 5)
  let assert Ok(_) = syn.register_worker("image_processors", "worker_1", load_info)
  
  // Find workers across the cluster
  case syn.find_worker("image_processors", "worker_1") {
    Ok(#(pid, #(cpu_usage, queue_size))) -> {
      // Send work to the least loaded worker
      process.send(pid, ProcessImage("photo.jpg"))
    }
    Error(_) -> // Worker not available, try another
  }
  
  // Join coordination group for consensus
  let assert Ok(_) = syn.join_coordination("leader_election")
  
  // Broadcast status for distributed coordination
  let status = json.object([
    #("node", json.string("worker_node_1")),
    #("load", json.float(0.3)),
    #("available", json.bool(True))
  ])
  
  let assert Ok(nodes_notified) = syn.broadcast_status("health_check", status)
  io.println("Status sent to " <> int.to_string(nodes_notified) <> " nodes")
}

// Advanced: Custom coordination patterns
pub fn consensus_example() {
  // Register with metadata for consensus algorithms
  let machine_status = #(queue_lengths: #(0, 5, 2), capacity: 100)
  let assert Ok(_) = syn.register("machines", "machine_1", machine_status)
  
  // Publish for distributed decision making
  let queue_status = json.object([
    #("machine_id", json.string("machine_1")),
    #("free_queue", json.int(0)),
    #("paid_queue", json.int(5)),
    #("capacity", json.int(100))
  ])
  
  let assert Ok(_) = syn.publish_json("coordination", "load_balancing", queue_status, fn(j) { j })
}

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

### PubSub - Type-Safe Distributed Messaging

**Real-time event broadcasting with JSON-based type safety! 📡**

```gleam
import glixir
import gleam/json
import gleam/dynamic/decode
import gleam/erlang/atom

// Define your message types
pub type UserEvent {
  PageView(user_id: String, page: String)
  Purchase(user_id: String, amount: Float)
}

// Create encoder/decoder for type safety
pub fn encode_user_event(event: UserEvent) -> String {
  case event {
    PageView(user_id, page) -> 
      json.object([
        #("type", json.string("page_view")),
        #("user_id", json.string(user_id)),
        #("page", json.string(page))
      ]) |> json.to_string
    
    Purchase(user_id, amount) ->
      json.object([
        #("type", json.string("purchase")),
        #("user_id", json.string(user_id)),
        #("amount", json.float(amount))
      ]) |> json.to_string
  }
}

pub fn decode_user_event(json_string: String) -> Result(UserEvent, String) {
  // Your custom decoder logic here
  json.decode(json_string, dynamic.decode3(
    PageView,
    dynamic.field("user_id", decode.string),
    dynamic.field("page", decode.string),
    dynamic.field("type", decode.string)
  ))
}

// Handler function for PubSub messages
pub fn handle_user_events(json_message: String) -> Nil {
  case decode_user_event(json_message) {
    Ok(PageView(user_id, page)) -> {
      io.println("User " <> user_id <> " viewed " <> page)
    }
    Ok(Purchase(user_id, amount)) -> {
      io.println("User " <> user_id <> " purchased $" <> float.to_string(amount))
    }
    Error(_) -> {
      io.println("Failed to decode user event")
    }
  }
}

pub fn pubsub_example() {
  // Start a phantom-typed PubSub system
  let assert Ok(_pubsub: glixir.PubSub(UserEvent)) = 
    glixir.pubsub_start(atom.create("user_events"))
  
  // Subscribe with your handler function
  let assert Ok(_) = glixir.pubsub_subscribe(
    atom.create("user_events"),
    "user:metrics",
    "my_app",  // Your module name
    "handle_user_events"  // Your handler function
  )
  
  // Broadcast type-safe events from anywhere
  let page_event = PageView("user_123", "/dashboard")
  let assert Ok(_) = glixir.pubsub_broadcast(
    atom.create("user_events"),
    "user:metrics", 
    page_event,
    encode_user_event  // Your encoder
  )
  
  let purchase_event = Purchase("user_123", 99.99)
  let assert Ok(_) = glixir.pubsub_broadcast(
    atom.create("user_events"),
    "user:metrics",
    purchase_event,
    encode_user_event
  )
  
  // Cleanup when done
  let assert Ok(_) = glixir.pubsub_unsubscribe(
    atom.create("user_events"), 
    "user:metrics"
  )
}
```

**Direct Actor Targeting Pattern:**
```gleam
// Perfect for metric actors that need their own identity
pub fn handle_metric_update(actor_id: String, json_message: String) -> Nil {
  case decode_metric_message(json_message) {
    Ok(metric) -> {
      // Update this specific actor's metrics
      io.println("Actor " <> actor_id <> " received metric: " <> metric.name)
      // ... update actor state
    }
    Error(_) -> {
      io.println("Invalid metric for actor: " <> actor_id)
    }
  }
}
```
// Subscribe each metric actor with its own ID
let assert Ok(_) = glixir.pubsub_subscribe_with_registry_key(
  atom.create("metrics_pubsub"),
  "metric:updates",
  "my_app",
  "handle_metric_update",
  "metric_actor_" <> actor_id  // Each actor gets its own key
)

**Multi-Message Handler Example:**
```gleam
// Single handler can process multiple message types!
pub fn handle_all_events(json_message: String) -> Nil {
  case decode_user_event(json_message) {
    Ok(user_event) -> handle_user_event(user_event)
    Error(_) -> 
      case decode_system_event(json_message) {
        Ok(system_event) -> handle_system_event(system_event)
        Error(_) -> io.println("Unknown message type: " <> json_message)
      }
  }
}
```

---

### Agent State Management (Now Type Safe!)

```gleam
import glixir
import gleam/dynamic/decode
import gleam/erlang/atom

pub fn main() {
  // Start an agent with initial state (Agent(Int))
  let assert Ok(counter) = glixir.start_agent(fn() { 42 })

  // Get state with a decoder (type safe!)
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

---

### Registry - Dynamic Actor Discovery

```gleam
import glixir
import gleam/erlang/process
import gleam/erlang/atom
import gleam/dynamic
import gleam/io

pub type UserMessage {
  RecordMetric(name: String, value: Float)
  GetStats
}

pub fn actor_discovery_example() {
  // Start phantom-typed registry for actor lookup
  let assert Ok(_registry: glixir.Registry(atom.Atom, UserMessage)) = 
    glixir.start_registry(atom.create("user_actors"))
  
  // Start a type-safe dynamic supervisor
  let assert Ok(supervisor) = glixir.start_dynamic_supervisor_named(
    atom.create("user_supervisor")
  )
  
  // String encoder for user ID args
  fn user_id_encode(user_id: String) -> List(dynamic.Dynamic) {
    [dynamic.string(user_id)]
  }
  
  // Simple decoder for replies
  fn simple_decode(_d: dynamic.Dynamic) -> Result(String, String) {
    Ok("started")
  }
  
  // Create a type-safe child spec
  let user_spec = glixir.child_spec(
    id: "user_123",
    module: "MyApp.UserActor", 
    function: "start_link",
    args: "user_123",  // Typed as String!
    restart: glixir.permanent,
    shutdown_timeout: 5000,
    child_type: glixir.worker,
    encode: user_id_encode,
  )
  
  // Start the child with compile-time type safety
  case glixir.start_dynamic_child(supervisor, user_spec, user_id_encode, simple_decode) {
    glixir.ChildStarted(_user_pid, _reply) -> {
      // Actor registers itself in the registry with typed key
      let user_subject = process.new_subject()
      let assert Ok(_) = glixir.register_subject(
        atom.create("user_actors"), 
        atom.create("user_123"),  // Typed Atom key
        user_subject,
        glixir.atom_key_encoder   // Required encoder
      )
      
      // Later... find and message the actor from anywhere!
      case glixir.lookup_subject(
        atom.create("user_actors"), 
        atom.create("user_123"),
        glixir.atom_key_encoder
      ) {
        Ok(subject) -> {
          process.send(subject, RecordMetric("page_views", 1.0))
          io.println("Metric sent to user actor! 📊")
        }
        Error(_) -> io.println("User actor not found")
      }
    }
    glixir.StartChildError(error) -> {
      io.println("Failed to start user actor: " <> error)
    }
  }
}
```

---

### GenServer Interop

```gleam
import glixir
import gleam/erlang/atom
import gleam/dynamic
import gleam/dynamic/decode

// Example: Counter server (request type is atom, reply type is Int)
pub fn main() {
  let assert Ok(server) = glixir.start_genserver("MyApp.Counter", dynamic.int(0))
  let assert Ok(count) = glixir.call_genserver(server, atom.create("get_count"), decode.int)
  io.debug(count)  // 0

  let assert Ok(_) = glixir.cast_genserver(server, atom.create("increment"))

  let assert Ok(count) = glixir.call_genserver(server, atom.create("get_count"), decode.int)
  io.debug(count)  // 1
}
```

---

## Type Safety Notes

While this library provides type-safe wrappers on the Gleam side, remember:

1. **Runtime Types**: Elixir/Erlang processes are dynamically typed at runtime
2. **Message Contracts**: Ensure message formats match between Gleam and Elixir
3. **JSON Serialization**: PubSub uses JSON for cross-process type safety
4. **Decoder Functions**: Always provide appropriate decoders for return values
5. **Error Handling**: Handle all potential decode and process errors
6. **Testing**: Test integration points thoroughly

---

## Real-World Use Cases

**TrackTags** - Auto-scaling metrics platform built with glixir:

* ✅ Dynamic user actors spawned per session
* ✅ Registry-based actor discovery by user ID  
* ✅ Real-time metric collection via type-safe PubSub
* ✅ Fault-tolerant supervision trees

---

## About the Author

Built by **Rahmi Pruitt** - Ex-Twitch/Amazon Engineer turned indie hacker, on a mission to bring Gleam to the mainstream! 🚀

*"Making concurrent programming delightful, one type at a time."*

---

**⭐ Star this repo if glixir helped you build something awesome!** Your support helps bring mature OTP tooling to the Gleam ecosystem.
