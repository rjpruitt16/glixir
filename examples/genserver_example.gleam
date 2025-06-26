// GenServer Integration Example
// Shows how to interact with Elixir GenServers from Gleam

import gleam/dynamic
import gleam/dynamic/decode
import gleam/int
import gleam/io
import glixir

pub fn main() {
  io.println("🚀 GenServer Integration Example")

  // Example 1: Simple counter GenServer
  counter_example()

  // Example 2: State management GenServer
  state_management_example()

  // Example 3: Named GenServer
  named_genserver_example()
}

/// Example 1: Simple counter GenServer
fn counter_example() {
  io.println("\n🔢 Counter GenServer Example")

  case glixir.start_genserver("MyApp.Counter", dynamic.int(0)) {
    Ok(counter) -> {
      io.println("✅ Counter GenServer started")

      // Get initial value
      case glixir.call_genserver(counter, dynamic.string("get"), decode.int) {
        Ok(value) -> io.println("📊 Initial count: " <> int.to_string(value))
        Error(e) -> io.println("❌ Failed to get count: " <> e)
      }

      // Increment the counter
      case glixir.cast_genserver(counter, dynamic.string("increment")) {
        Ok(_) -> io.println("⬆️  Counter incremented")
        Error(e) -> io.println("❌ Failed to increment: " <> e)
      }

      // Increment by a specific amount
      let increment_by_5 =
        dynamic.array([dynamic.string("increment_by"), dynamic.int(5)])
      case glixir.cast_genserver(counter, increment_by_5) {
        Ok(_) -> io.println("📈 Counter incremented by 5")
        Error(e) -> io.println("❌ Failed to increment by 5: " <> e)
      }

      // Get final value
      case glixir.call_genserver(counter, dynamic.string("get"), decode.int) {
        Ok(value) -> io.println("🎯 Final count: " <> int.to_string(value))
        Error(e) -> io.println("❌ Failed to get final count: " <> e)
      }

      // Stop the GenServer
      case glixir.stop_genserver(counter) {
        Ok(_) -> io.println("🛑 Counter stopped")
        Error(e) -> io.println("❌ Failed to stop counter: " <> e)
      }
    }
    Error(e) -> io.println("❌ Failed to start counter: " <> e)
  }
}

/// Example 2: State management with complex data
fn state_management_example() {
  io.println("\n🗂️  State Management Example")

  // Start a GenServer that manages a map/dictionary
  let initial_state =
    dynamic.properties([
      #(dynamic.string("users"), dynamic.array([])),
      #(
        dynamic.string("config"),
        dynamic.properties([
          #(dynamic.string("version"), dynamic.string("1.0")),
          #(dynamic.string("debug"), dynamic.bool(True)),
        ]),
      ),
    ])

  case glixir.start_genserver("MyApp.StateManager", initial_state) {
    Ok(manager) -> {
      io.println("✅ State manager started")

      // Add a user
      let add_user_msg =
        dynamic.array([
          dynamic.string("add_user"),
          dynamic.properties([
            #(dynamic.string("id"), dynamic.int(1)),
            #(dynamic.string("name"), dynamic.string("Alice")),
            #(dynamic.string("email"), dynamic.string("alice@example.com")),
          ]),
        ])

      case glixir.cast_genserver(manager, add_user_msg) {
        Ok(_) -> io.println("👤 User added to state")
        Error(e) -> io.println("❌ Failed to add user: " <> e)
      }

      // Get user count
      case
        glixir.call_genserver(manager, dynamic.string("user_count"), decode.int)
      {
        Ok(count) -> io.println("👥 User count: " <> int.to_string(count))
        Error(e) -> io.println("❌ Failed to get user count: " <> e)
      }

      // Get config version
      let get_config =
        dynamic.array([dynamic.string("get_config"), dynamic.string("version")])
      case glixir.call_genserver(manager, get_config, decode.string) {
        Ok(version) -> io.println("⚙️  Config version: " <> version)
        Error(e) -> io.println("❌ Failed to get config: " <> e)
      }

      // Update config
      let update_config =
        dynamic.array([
          dynamic.string("update_config"),
          dynamic.string("version"),
          dynamic.string("1.1"),
        ])

      case glixir.cast_genserver(manager, update_config) {
        Ok(_) -> io.println("🔄 Config updated")
        Error(e) -> io.println("❌ Failed to update config: " <> e)
      }

      // Verify update
      case glixir.call_genserver(manager, get_config, decode.string) {
        Ok(version) -> io.println("✅ Updated version: " <> version)
        Error(e) -> io.println("❌ Failed to verify update: " <> e)
      }

      let _ = glixir.stop_genserver(manager)
    }
    Error(e) -> io.println("❌ Failed to start state manager: " <> e)
  }
}

/// Example 3: Named GenServer for global access
fn named_genserver_example() {
  io.println("\n🏷️  Named GenServer Example")

  case
    glixir.start_genserver_named(
      "MyApp.Cache",
      "global_cache",
      dynamic.properties([]),
    )
  {
    Ok(cache) -> {
      io.println("✅ Named cache GenServer started")

      // Put a value in cache
      let put_msg =
        dynamic.array([
          dynamic.string("put"),
          dynamic.string("user:123"),
          dynamic.properties([
            #(dynamic.string("name"), dynamic.string("Bob")),
            #(dynamic.string("age"), dynamic.int(30)),
          ]),
        ])

      case glixir.cast_genserver(cache, put_msg) {
        Ok(_) -> io.println("💾 Value cached")
        Error(e) -> io.println("❌ Failed to cache: " <> e)
      }

      // Get value from cache
      let get_msg =
        dynamic.array([dynamic.string("get"), dynamic.string("user:123")])
      case glixir.call_genserver(cache, get_msg, decode.dynamic) {
        Ok(value) -> {
          io.println("🔍 Retrieved from cache: " <> string.inspect(value))
        }
        Error(e) -> io.println("❌ Failed to get from cache: " <> e)
      }

      // Cache stats
      case
        glixir.call_genserver(cache, dynamic.string("stats"), decode.dynamic)
      {
        Ok(stats) -> io.println("📈 Cache stats: " <> string.inspect(stats))
        Error(e) -> io.println("❌ Failed to get stats: " <> e)
      }

      // Clear cache
      case glixir.cast_genserver(cache, dynamic.string("clear")) {
        Ok(_) -> io.println("🧹 Cache cleared")
        Error(e) -> io.println("❌ Failed to clear cache: " <> e)
      }

      let _ = glixir.stop_genserver(cache)
    }
    Error(e) -> io.println("❌ Failed to start named cache: " <> e)
  }
}

/// Example 4: Error handling and timeouts
pub fn timeout_and_error_example() {
  io.println("\n⏰ Timeout and Error Handling Example")

  case glixir.start_genserver("MyApp.SlowServer", dynamic.string("initial")) {
    Ok(server) -> {
      io.println("✅ Slow server started")

      // Normal call that should work
      case
        glixir.call_genserver(
          server,
          dynamic.string("fast_operation"),
          decode.string,
        )
      {
        Ok(result) -> io.println("⚡ Fast operation result: " <> result)
        Error(e) -> io.println("❌ Fast operation failed: " <> e)
      }

      // Call that might timeout
      case
        glixir.call_genserver_timeout(
          server,
          dynamic.string("slow_operation"),
          decode.string,
          1000,
        )
      {
        Ok(result) -> io.println("🐌 Slow operation result: " <> result)
        Error(e) -> io.println("⏰ Slow operation failed/timed out: " <> e)
      }

      // Call that should cause an error
      case
        glixir.call_genserver(
          server,
          dynamic.string("error_operation"),
          decode.string,
        )
      {
        Ok(result) -> io.println("Unexpected success: " <> result)
        Error(e) -> io.println("✅ Expected error handled: " <> e)
      }

      let _ = glixir.stop_genserver(server)
    }
    Error(e) -> io.println("❌ Failed to start slow server: " <> e)
  }
}

/// Example 5: Working with custom message formats
pub fn custom_message_example() {
  io.println("\n📨 Custom Message Format Example")

  case glixir.start_genserver("MyApp.MessageHandler", dynamic.string("ready")) {
    Ok(handler) -> {
      io.println("✅ Message handler started")

      // Complex message with nested data
      let complex_message =
        dynamic.properties([
          #(dynamic.string("action"), dynamic.string("process_data")),
          #(
            dynamic.string("payload"),
            dynamic.properties([
              #(dynamic.string("user_id"), dynamic.int(456)),
              #(
                dynamic.string("data"),
                dynamic.array([
                  dynamic.string("item1"),
                  dynamic.string("item2"),
                  dynamic.string("item3"),
                ]),
              ),
              #(
                dynamic.string("metadata"),
                dynamic.properties([
                  #(dynamic.string("timestamp"), dynamic.int(1_640_995_200)),
                  #(dynamic.string("source"), dynamic.string("api")),
                ]),
              ),
            ]),
          ),
        ])

      case glixir.cast_genserver(handler, complex_message) {
        Ok(_) -> io.println("📤 Complex message sent")
        Error(e) -> io.println("❌ Failed to send complex message: " <> e)
      }

      // Get processing status
      case
        glixir.call_genserver(
          handler,
          dynamic.string("get_status"),
          decode.string,
        )
      {
        Ok(status) -> io.println("📊 Processing status: " <> status)
        Error(e) -> io.println("❌ Failed to get status: " <> e)
      }

      let _ = glixir.stop_genserver(handler)
    }
    Error(e) -> io.println("❌ Failed to start message handler: " <> e)
  }
}
