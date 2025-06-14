import genserver
import gleam/erlang/process
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

// Test Agent functionality (this will definitely work)
pub fn agent_basic_test() {
  // Start an agent with initial value 0
  let assert Ok(agent) = genserver.agent_start(fn() { 0 })

  // Get the initial value
  let initial_value = genserver.agent_get(agent, fn(state) { state })
  initial_value |> should.equal(0)

  // Update the state
  let assert Ok(_) = genserver.agent_update(agent, fn(state) { state + 42 })

  // Get the updated value
  let updated_value = genserver.agent_get(agent, fn(state) { state })
  updated_value |> should.equal(42)

  // Stop the agent
  let assert Ok(_) = genserver.agent_stop(agent)
}

pub fn agent_string_state_test() {
  // Test with string state
  let assert Ok(agent) = genserver.agent_start(fn() { "hello" })

  let value = genserver.agent_get(agent, fn(state) { state <> " world" })
  value |> should.equal("hello world")

  let assert Ok(_) = genserver.agent_update(agent, fn(_) { "goodbye" })

  let new_value = genserver.agent_get(agent, fn(state) { state })
  new_value |> should.equal("goodbye")

  let assert Ok(_) = genserver.agent_stop(agent)
}

pub fn atom_creation_test() {
  let test_atom = genserver.atom("test_atom")
  // We can't easily test atom equality, but we can test it doesn't crash
  test_atom |> should.not_equal(genserver.atom("different_atom"))
}

pub fn tagged_message_test() {
  let my_pid = process.self()
  let message = genserver.tagged_message("test_event", my_pid, "test_data")

  // Should create a 3-tuple with atom, pid, and content
  let #(_tag, from_pid, content) = message
  from_pid |> should.equal(my_pid)
  content |> should.equal("test_data")
}
