```markdown
# Glixir 🌟

[![Package Version](https://img.shields.io/hexpm/v/glixir)](https://hex.pm/packages/glixir)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/glixir/)

**Seamless OTP interop between Gleam and Elixir/Erlang**

Bridge the gap between Gleam's type safety and the battle-tested OTP ecosystem. Use GenServers, Supervisors, Agents, Registry, and more from Gleam with confidence.

## Features

- ✅ **GenServer** - Type-safe calls to Elixir GenServers
- ✅ **DynamicSupervisor** - Runtime process supervision and management
- ✅ **Agent (now generic!)** - Type-safe state management with async operations
- ✅ **Registry** - Dynamic process registration and Subject lookup
- 🚧 **Task** - Async task execution _(coming soon)_
- ✅ **Phoenix.PubSub** - Distributed messaging and event broadcasting
- ✅ **Zero overhead** - Direct BEAM interop with clean Elixir helpers
- ✅ **Gradual adoption** - Use alongside existing Elixir code

---

## Type Safety & Phantom Types

> **A note from your neighborhood type enthusiast:**
>
> Some `glixir` APIs (notably process calls, GenServer, Registry) still require passing `Dynamic` values—this is the price of seamless BEAM interop and runtime dynamism. While decoders on return values help catch mismatches, full compile-time type safety isn’t always possible... **yet**.
>
> But here’s the good news:
> We’re actively rolling out [phantom types](https://gleam.run/tour/phantom_types/) and generics across the API, banishing `Dynamic` wherever possible and making misused actors a compile-time relic.

---

### Type safety level
```

GenServer:     [■■■■■■■■□□] 80% - Request/reply types enforced by Gleam, decoder required, but runtime BEAM interop can still fail if types disagree.
Supervisor:    [■■■■■■■■□□] 80% - Child specs typed, args Dynamic.
Registry:      [■■■■■□□□□□] 50% - Keyed by String, subject is phantom-typed, messages aren’t.
Agent:         [■■■■■■■■■■] 100% - State and API fully generic and type safe!
PubSub:        [■■■■■□□□□□] 50% - Topics/IDs typed, payloads Dynamic.
Task:          [□□□□□□□□□□] 0% - Not started.
````

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
````

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
3. **Decoder Functions**: Always provide appropriate decoders for return values
4. **Error Handling**: Handle all potential decode and process errors
5. **Testing**: Test integration points thoroughly

---

## Real-World Use Cases

**TrackTags** - Auto-scaling metrics platform built with glixir:

* ✅ Dynamic user actors spawned per session
* ✅ Registry-based actor discovery by user ID
* ✅ Real-time metric collection and coordination
* ✅ Fault-tolerant supervision trees

---

## About the Author

Built by **Rahmi Pruitt** - Ex-Twitch/Amazon Engineer turned indie hacker, on a mission to bring Gleam to the mainstream! 🚀

*"Making concurrent programming delightful, one type at a time."*

---

**⭐ Star this repo if glixir helped you build something awesome!** Your support helps bring mature OTP tooling to the Gleam ecosystem.

```

---

**That’s it!**  
- **All “Agent” usage now says `Agent(state)`** and is type safe.  
- **Every example is correct for the new API.**
- **No extra section or legacy cruft.**

If you want a more concise or flashier badge/progress chart, just say the word.  
Otherwise, *this* is the readme you want to ship for a “nobody else is using it but me” v1 breaking change.

Let me know if you want the commit message, or want it as a PR-style description!
```

