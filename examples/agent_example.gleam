// Agent State Management Example
// Shows different patterns for using Agents for state management

import gleam/dynamic
import gleam/dynamic/decode
import gleam/int
import gleam/io
import gleam/list
import glixir

pub fn main() {
  io.println("🚀 Agent State Management Examples")
  
  // Example 1: Simple counter
  simple_counter_example()
  
  // Example 2: Complex state management
  complex_state_example()
  
  // Example 3: Multiple agents coordination
  multi_agent_example()
  
  // Example 4: Agent as cache
  cache_agent_example()
}

/// Example 1: Simple counter agent
fn simple_counter_example() {
  io.println("\n🔢 Simple Counter Agent")
  
  case glixir.start_agent(fn() { 0 }) {
    Ok(counter) -> {
      io.println("✅ Counter agent started")
      
      // Get initial value
      case glixir.get_agent(counter, fn(n) { n }, decode.int) {
        Ok(value) -> io.println("📊 Initial value: " <> int.to_string(value))
        Error(e) -> io.println("❌ Failed to get value: " <> e)
      }
      
      // Update the counter
      case glixir.update_agent(counter, fn(n) { n + 1 }) {
        Ok(_) -> io.println("⬆️  Counter incremented")
        Error(e) -> io.println("❌ Failed to increment: " <> e)
      }
      
      // Update by 10
      case glixir.update_agent(counter, fn(n) { n + 10 }) {
        Ok(_) -> io.println("📈 Counter increased by 10")
        Error(e) -> io.println("❌ Failed to increase: " <> e)
      }
      
      // Get and update in one operation
      case glixir.get_and_update_agent(counter, fn(n) { #(n, n * 2) }, decode.int) {
        Ok(old_value) -> {
          io.println("🔄 Got old value: " <> int.to_string(old_value) <> ", doubled the state")
        }
        Error(e) -> io.println("❌ Failed get_and_update: " <> e)
      }
      
      // Get final value
      case glixir.get_agent(counter, fn(n) { n }, decode.int) {
        Ok(value) -> io.println("🎯 Final value: " <> int.to_string(value))
        Error(e) -> io.println("❌ Failed to get final value: " <> e)
      }
      
      // Stop the agent
      case glixir.stop_agent(counter) {
        Ok(_) -> io.println("🛑 Counter agent stopped")
        Error(e) -> io.println("❌ Failed to stop agent: " <> e)
      }
    }
    Error(e) -> io.println("❌ Failed to start counter agent: " <> e)
  }
}

/// Example 2: Complex state with maps/objects
fn complex_state_example() {
  io.println("\n🗂️  Complex State Agent")
  
  // Initial state: user profile
  let initial_profile = fn() {
    dynamic.properties([
      #(dynamic.string("name"), dynamic.string("Alice")),
      #(dynamic.string("age"), dynamic.int(25)),
      #(dynamic.string("email"), dynamic.string("alice@example.com")),
      #(dynamic.string("preferences"), dynamic.properties([
        #(dynamic.string("theme"), dynamic.string("dark")),
        #(dynamic.string("notifications"), dynamic.bool(True))
      ])),
      #(dynamic.string("friends"), dynamic.array([
        dynamic.string("Bob"),
        dynamic.string("Charlie")
      ]))
    ])
  }
  
  case glixir.start_agent(initial_profile) {
    Ok(profile) -> {
      io.println("✅ Profile agent started")
      
      // Get user name
      case glixir.get_agent(profile, fn(state) { 
        // In a real app, you'd parse the dynamic state properly
        state 
      }, decode.dynamic) {
        Ok(state) -> io.println("👤 Profile loaded: " <> string.inspect(state))
        Error(e) -> io.println("❌ Failed to get profile: " <> e)
      }
      
      // Update age
      case glixir.update_agent(profile, fn(state) {
        // In a real app, you'd properly update the dynamic structure
        // This is simplified for the example
        dynamic.properties([
          #(dynamic.string("name"), dynamic.string("Alice")),
          #(dynamic.string("age"), dynamic.int(26)),  // Birthday!
          #(dynamic.string("email"), dynamic.string("alice@example.com")),
          #(dynamic.string("preferences"), dynamic.properties([
            #(dynamic.string("theme"), dynamic.string("dark")),
            #(dynamic.string("notifications"), dynamic.bool(True))
          ])),
          #(dynamic.string("friends"), dynamic.array([
            dynamic.string("Bob"),
            dynamic.string("Charlie"),
            dynamic.string("David")  // New friend!
          ]))
        ])
      }) {
        Ok(_) -> io.println("🎂 Profile updated (birthday + new friend)")
        Error(e) -> io.println("❌ Failed to update profile: " <> e)
      }
      
      // Get friend count
      case glixir.get_agent(profile, fn(_state) { 
        // In practice, you'd extract friends array and count it
        3  // Simplified
      }, decode.int) {
        Ok(count) -> io.println("👥 Friend count: " <> int.to_string(count))
        Error(e) -> io.println("❌ Failed to get friend count: " <> e)
      }
      
      let _ = glixir.stop_agent(profile)
    }
    Error(e) -> io.println("❌ Failed to start profile agent: " <> e)
  }
}

/// Example 3: Multiple agents working together
fn multi_agent_example() {
  io.println("\n🤝 Multi-Agent Coordination")
  
  // Start multiple agents for different concerns
  case #(
    glixir.start_agent(fn() { dynamic.properties([]) }),  // Users
    glixir.start_agent(fn() { 0 }),                       // Stats  
    glixir.start_agent(fn() { dynamic.array([]) })        // Events
  ) {
    #(Ok(users), Ok(stats), Ok(events)) -> {
      io.println("✅ All agents started")
      
      // Simulate user registration
      register_user(users, stats, events, "alice@example.com")
      register_user(users, stats, events, "bob@example.com") 
      
      // Show final stats
      show_system_stats(users, stats, events)
      
      // Cleanup
      let _ = glixir.stop_agent(users)
      let _ = glixir.stop_agent(stats)  
      let _ = glixir.stop_agent(events)
    }
    _ -> io.println("❌ Failed to start one or more agents")
  }
}

fn register_user(users_agent, stats_agent, events_agent, email: String) {
  io.println("📝 Registering user: " <> email)
  
  // Add user (simplified)
  let _ = glixir.update_agent(users_agent, fn(users) {
    // In practice, you'd properly manage the users map
    users
  })
  
  // Increment stats
  let _ = glixir.update_agent(stats_agent, fn(count) { count + 1 })
  
  // Log event
  let _ = glixir.update_agent(events_agent, fn(events) {
    // In practice, you'd add a proper event structure
    events
  })
  
  io.println("✅ User " <> email <> " registered")
}

fn show_system_stats(users_agent, stats_agent, events_agent) {
  io.println("\n📊 System Statistics:")
  
  case glixir.get_agent(stats_agent, fn(n) { n }, decode.int) {
    Ok(count) -> io.println("👥 Total users: " <> int.to_string(count))
    Error(_) -> io.println("❌ Failed to get user count")
  }
  
  // In a real app, you'd get actual metrics from each agent
  io.println("📈 System healthy")
}

/// Example 4: Agent as an application cache
fn cache_agent_example() {
  io.println("\n🗄️  Cache Agent Example")
  
  case glixir.start_agent(fn() { dynamic.properties([]) }) {
    Ok(cache) -> {
      io.println("✅ Cache agent started")
      
      // Cache some values
      cache_set(cache, "user:123", "Alice")
      cache_set(cache, "user:456", "Bob")
      cache_set(cache, "config:theme", "dark")
      
      // Retrieve values
      cache_get(cache, "user:123")
      cache_get(cache, "user:456") 
      cache_get(cache, "config:theme")
      cache_get(cache, "nonexistent")  // Should not exist
      
      // Show cache size
      case glixir.get_agent(cache, fn(_state) { 
        // In practice, you'd count the keys in the state
        3  // Simplified
      }, decode.int) {
        Ok(size) -> io.println("📦 Cache size: " <> int.to_string
