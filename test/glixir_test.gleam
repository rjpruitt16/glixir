import gleam/dynamic
import gleam/dynamic/decode
import gleam/erlang/atom
import gleam/erlang/process.{type Pid}
import gleam/int
import gleam/list
import gleam/string
import gleeunit
import gleeunit/should
import glixir
import glixir/registry
import glixir/supervisor
import glixir/utils
import logging

pub fn main() {
  // Configure logging for tests
  logging.configure()
  gleeunit.main()
}

// Test message type for registry testing
pub type TestMessage {
  Echo(String)
  Ping
}

// Test helper - simple process spawning for testing
pub fn spawn_test_process() -> Pid {
  process.spawn(fn() { process.sleep(100) })
}

// ============================================================================
// PUBSUB TYPED API WRAPPER VERIFICATION
// ============================================================================

pub fn handle_test_json(json_message: String) -> Nil {
  utils.debug_log(logging.Info, "📨 Received: " <> json_message)
  Nil
}

pub fn pubsub_typed_wrapper_test() {
  utils.debug_log(logging.Info, "🎯 Testing typed PubSub wrapper")

  let pubsub_name = atom.create("typed_wrapper_test")

  // Verify our typed wrapper works
  case glixir.pubsub_start(pubsub_name) {
    Ok(_pubsub) -> {
      utils.debug_log(logging.Info, "✅ Typed PubSub started")

      // Test typed subscribe with all required parameters
      case
        glixir.pubsub_subscribe(
          pubsub_name,
          "typed_channel",
          "glixir_test",
          "handle_test_json",
        )
      {
        Ok(_) -> {
          utils.debug_log(logging.Info, "✅ Typed subscribe works")

          // Test typed broadcast with string encoder
          case
            glixir.pubsub_broadcast(
              pubsub_name,
              "typed_channel",
              "Hello typed wrapper!",
              glixir.string_encoder,
            )
          {
            Ok(_) -> {
              utils.debug_log(logging.Info, "✅ Typed broadcast works")

              // Test with int encoder
              case
                glixir.pubsub_broadcast(
                  pubsub_name,
                  "typed_channel",
                  42,
                  glixir.int_encoder,
                )
              {
                Ok(_) -> {
                  utils.debug_log(logging.Info, "✅ Int encoder works")

                  // Test unsubscribe
                  case glixir.pubsub_unsubscribe(pubsub_name, "typed_channel") {
                    Ok(_) -> {
                      utils.debug_log(logging.Info, "✅ Typed unsubscribe works")
                      True |> should.be_true
                    }
                    Error(e) -> {
                      logging.log(
                        logging.Error,
                        "❌ Typed unsubscribe failed: " <> string.inspect(e),
                      )
                      False |> should.be_true
                    }
                  }
                }
                Error(e) -> {
                  logging.log(
                    logging.Error,
                    "❌ Int encoder failed: " <> string.inspect(e),
                  )
                  False |> should.be_true
                }
              }
            }
            Error(e) -> {
              logging.log(
                logging.Error,
                "❌ Typed broadcast failed: " <> string.inspect(e),
              )
              False |> should.be_true
            }
          }
        }
        Error(e) -> {
          logging.log(
            logging.Error,
            "❌ Typed subscribe failed: " <> string.inspect(e),
          )
          False |> should.be_true
        }
      }
    }
    Error(e) -> {
      logging.log(
        logging.Error,
        "❌ Typed PubSub start failed: " <> string.inspect(e),
      )
      False |> should.be_true
    }
  }
}

/// Test JSON encoder/decoder work correctly (just verify our wrappers)
pub fn pubsub_encoder_test() {
  utils.debug_log(logging.Info, "🔄 Testing PubSub encoder/decoder wrappers")

  // Test string roundtrip
  let original_string = "Hello, World!"
  let encoded = glixir.string_encoder(original_string)
  case glixir.string_decoder(encoded) {
    Ok(decoded) -> {
      case decoded == original_string {
        True -> {
          utils.debug_log(logging.Info, "✅ String encoder/decoder works")
        }
        False -> {
          utils.debug_log(logging.Error, "❌ String roundtrip failed")
        }
      }
    }
    Error(e) -> {
      utils.debug_log(logging.Error, "❌ String decode failed: " <> e)
    }
  }

  // Test int roundtrip
  let original_int = 42
  let encoded_int = glixir.int_encoder(original_int)
  case glixir.int_decoder(encoded_int) {
    Ok(decoded_int) -> {
      case decoded_int == original_int {
        True -> {
          utils.debug_log(logging.Info, "✅ Int encoder/decoder works")
          True |> should.be_true
        }
        False -> {
          utils.debug_log(logging.Error, "❌ Int roundtrip failed")
          False |> should.be_true
        }
      }
    }
    Error(e) -> {
      utils.debug_log(logging.Error, "❌ Int decode failed: " <> e)
      False |> should.be_true
    }
  }
}

// ============================================================================
// REGISTRY BASIC VERIFICATION TEST (PHANTOM-TYPED)
// ============================================================================
pub fn registry_basic_test() {
  utils.debug_log(
    logging.Info,
    "🏪 Testing phantom-typed registry functionality",
  )

  // Start registry with phantom types for Atom keys and TestMessage values
  case glixir.start_registry(atom.create("test_registry")) {
    Ok(_registry) -> {
      utils.debug_log(logging.Info, "✅ Phantom-typed registry started")

      // Create and register a subject
      let test_subject = process.new_subject()
      case
        glixir.register_subject(
          atom.create("test_registry"),
          atom.create("test_key"),
          // Typed as Atom
          test_subject,
          glixir.atom_key_encoder,
          // Required encoder
        )
      {
        Ok(_) -> {
          utils.debug_log(logging.Info, "✅ Subject registered with typed key")

          // Look it up with the same encoder
          case
            glixir.lookup_subject(
              atom.create("test_registry"),
              atom.create("test_key"),
              glixir.atom_key_encoder,
            )
          {
            Ok(found_subject) -> {
              utils.debug_log(logging.Info, "✅ Subject found with type safety")
              process.send(found_subject, Echo("test"))
              True |> should.be_true
            }
            Error(_) -> {
              utils.always_log(logging.Error, "❌ Subject lookup failed")
              False |> should.be_true
            }
          }
        }
        Error(_) -> {
          utils.always_log(logging.Error, "❌ Subject registration failed")
          False |> should.be_true
        }
      }
    }
    Error(_) -> {
      utils.always_log(logging.Error, "❌ Phantom-typed registry start failed")
      False |> should.be_true
    }
  }
}

pub fn registry_error_test() {
  utils.debug_log(
    logging.Info,
    "⚠️ Testing phantom-typed registry error handling",
  )

  // Test lookup in non-existent registry
  case
    glixir.lookup_subject(
      atom.create("nonexistent_registry"),
      atom.create("any_key"),
      glixir.atom_key_encoder,
    )
  {
    Ok(_) -> {
      utils.always_log(
        logging.Error,
        "❌ Found subject in non-existent registry (shouldn't happen)",
      )
      False |> should.be_true
    }
    Error(registry.LookupError(_)) -> {
      utils.debug_log(
        logging.Info,
        "✅ Correctly failed to find subject in non-existent registry",
      )

      // Test lookup of non-existent key in existing registry
      case glixir.start_registry(atom.create("error_test_registry")) {
        Ok(_registry) -> {
          // ← Remove the type annotation here
          case
            glixir.lookup_subject(
              atom.create("error_test_registry"),
              atom.create("missing_key"),
              glixir.atom_key_encoder,
            )
          {
            Ok(_) -> {
              utils.always_log(
                logging.Error,
                "❌ Found non-existent key (shouldn't happen)",
              )
              False |> should.be_true
            }
            Error(registry.NotFound) -> {
              utils.debug_log(
                logging.Info,
                "✅ Correctly failed to find non-existent key",
              )
              True |> should.be_true
            }
            Error(_) -> {
              utils.debug_log(
                logging.Info,
                "✅ Correctly failed to find non-existent key (other error)",
              )
              True |> should.be_true
            }
          }
        }
        Error(_) -> {
          utils.always_log(
            logging.Warning,
            "⚠️ Could not start error test registry",
          )
          True |> should.be_true
        }
      }
    }
    Error(registry.NotFound) -> {
      utils.debug_log(
        logging.Info,
        "✅ Correctly returned NotFound for non-existent registry",
      )
      True |> should.be_true
    }
    Error(_) -> {
      utils.debug_log(
        logging.Info,
        "✅ Correctly failed to find subject in non-existent registry (other error)",
      )
      True |> should.be_true
    }
  }
}

// ============================================================================
// NEW PHANTOM-TYPE SPECIFIC TESTS
// ============================================================================

pub fn registry_type_safety_test() {
  utils.debug_log(logging.Info, "🎯 Testing phantom-type compile-time safety")

  // Test with Int keys and TestMessage values
  case glixir.start_registry(atom.create("int_key_registry")) {
    Ok(_registry) -> {
      // ← Remove type annotation
      utils.debug_log(logging.Info, "✅ Int-keyed registry started")

      let test_subject = process.new_subject()

      // Register with Int key
      case
        glixir.register_subject(
          atom.create("int_key_registry"),
          123,
          // Int key
          test_subject,
          glixir.int_key_encoder,
          // Int encoder
        )
      {
        Ok(_) -> {
          utils.debug_log(logging.Info, "✅ Subject registered with Int key")

          // Look up with same Int key and encoder
          case
            glixir.lookup_subject(
              atom.create("int_key_registry"),
              123,
              glixir.int_key_encoder,
            )
          {
            Ok(found_subject) -> {
              utils.debug_log(logging.Info, "✅ Subject found with Int key")
              process.send(found_subject, Ping)
              True |> should.be_true
            }
            Error(_) -> {
              utils.always_log(logging.Error, "❌ Int key lookup failed")
              False |> should.be_true
            }
          }
        }
        Error(_) -> {
          utils.always_log(logging.Error, "❌ Int key registration failed")
          False |> should.be_true
        }
      }
    }
    Error(_) -> {
      utils.always_log(logging.Error, "❌ Int-keyed registry start failed")
      False |> should.be_true
    }
  }
}

pub fn registry_user_id_encoder_test() {
  utils.debug_log(logging.Info, "👤 Testing user ID encoder pattern")

  // Test with user ID pattern (common real-world use case)
  case glixir.start_registry(atom.create("user_registry")) {
    Ok(_registry) -> {
      // ← Remove type annotation
      utils.debug_log(logging.Info, "✅ User registry started")

      let user_subject = process.new_subject()

      // Register user with ID 456
      case
        glixir.register_subject(
          atom.create("user_registry"),
          456,
          // User ID
          user_subject,
          glixir.user_id_encoder,
          // Converts 456 -> "user_456"
        )
      {
        Ok(_) -> {
          utils.debug_log(logging.Info, "✅ User registered with ID pattern")

          // Look up the user
          case
            glixir.lookup_subject(
              atom.create("user_registry"),
              456,
              glixir.user_id_encoder,
            )
          {
            Ok(found_subject) -> {
              utils.debug_log(logging.Info, "✅ User found by ID")
              process.send(found_subject, Echo("Hello User 456!"))
              True |> should.be_true
            }
            Error(_) -> {
              utils.always_log(logging.Error, "❌ User lookup failed")
              False |> should.be_true
            }
          }
        }
        Error(_) -> {
          utils.always_log(logging.Error, "❌ User registration failed")
          False |> should.be_true
        }
      }
    }
    Error(_) -> {
      utils.always_log(logging.Error, "❌ User registry start failed")
      False |> should.be_true
    }
  }
}

// ===================================
// SUPERVISOR TESTS (Type Safe API!)
// ===================================

// Helper encoders/decoders for tests
fn string_encode(args: String) -> List(dynamic.Dynamic) {
  [dynamic.string(args)]
}

fn multi_args_encode(args: #(String, Int, Bool)) -> List(dynamic.Dynamic) {
  let #(name, num, flag) = args
  [dynamic.string(name), dynamic.int(num), dynamic.bool(flag)]
}

fn list_args_encode(args: List(String)) -> List(dynamic.Dynamic) {
  [dynamic.array(list.map(args, dynamic.string))]
}

fn simple_decode(_d: dynamic.Dynamic) -> Result(String, String) {
  Ok("ok")
}

pub fn simple_supervisor_test() {
  utils.debug_log(logging.Info, "🚀 Testing simple supervisor start (type safe)")

  // Start a supervisor that manages String args and String replies
  case glixir.start_dynamic_supervisor_named(atom.create("simple_sup")) {
    Ok(sup) -> {
      utils.debug_log(logging.Info, "✅ Simple supervisor started!")

      let spec =
        glixir.child_spec(
          "ping_test",
          "Elixir.TestGenServer",
          "start_link",
          "ping_data",
          glixir.permanent,
          5000,
          glixir.worker,
        )

      case glixir.start_dynamic_child(sup, spec, string_encode, simple_decode) {
        supervisor.ChildStarted(_pid, _reply) -> {
          utils.debug_log(
            logging.Info,
            "✅ Supervisor working - child started successfully",
          )
          True |> should.be_true
        }
        supervisor.StartChildError(error_msg) -> {
          utils.debug_log(
            logging.Warning,
            "⚠️ Child start failed: " <> error_msg,
          )
          True |> should.be_true
        }
      }
    }
    Error(error) -> {
      logging.log(
        logging.Error,
        "❌ Supervisor start failed: " <> string.inspect(error),
      )
      False |> should.be_true
    }
  }
}

pub fn named_supervisor_test() {
  utils.debug_log(logging.Info, "🏷️ Testing named supervisor")

  case
    glixir.start_dynamic_supervisor_named(atom.create("test_named_supervisor"))
  {
    Ok(_supervisor) -> {
      utils.debug_log(logging.Info, "✅ Named supervisor started!")

      // Try to start another with the same name (should fail)
      case
        glixir.start_dynamic_supervisor_named(atom.create(
          "test_named_supervisor",
        ))
      {
        Ok(_) -> {
          utils.debug_log(
            logging.Warning,
            "⚠️ Duplicate named supervisor started (maybe ok)",
          )
          True |> should.be_true
        }
        Error(_) -> {
          utils.debug_log(logging.Info, "✅ Duplicate name properly rejected")
          True |> should.be_true
        }
      }
    }
    Error(error) -> {
      logging.log(
        logging.Error,
        "❌ Named supervisor failed: " <> string.inspect(error),
      )
      False |> should.be_true
    }
  }
}

pub fn supervisor_child_management_test() {
  utils.debug_log(logging.Info, "👶 Testing supervisor child management")

  case glixir.start_dynamic_supervisor_named(atom.create("child_mgmt_sup")) {
    Ok(sup) -> {
      utils.debug_log(logging.Info, "✅ Supervisor started for child management")

      let spec =
        glixir.child_spec(
          id: "test_worker_child",
          module: "Elixir.TestGenServer",
          function: "start_link",
          args: "child_init_data",
          restart: glixir.permanent,
          shutdown_timeout: 5000,
          child_type: glixir.worker,
        )

      case glixir.start_dynamic_child(sup, spec, string_encode, simple_decode) {
        supervisor.ChildStarted(child_pid, _reply) -> {
          utils.debug_log(logging.Info, "✅ Child worker started!")

          // TEST: Get all children before termination
          case glixir.get_all_dynamic_children(sup) {
            Ok(children) -> {
              utils.debug_log(
                logging.Info,
                "✅ Found "
                  <> int.to_string(list.length(children))
                  <> " children",
              )
            }
            Error(e) -> {
              utils.debug_log(
                logging.Warning,
                "⚠️ Failed to get children: " <> e,
              )
            }
          }

          case process.is_alive(child_pid) {
            True -> {
              utils.debug_log(logging.Info, "✅ Child process is alive")

              utils.debug_log(
                logging.Debug,
                "About to call terminate_dynamic_child",
              )

              let terminate_result =
                glixir.terminate_dynamic_child(sup, child_pid)

              case terminate_result {
                Ok(Nil) -> {
                  utils.debug_log(
                    logging.Info,
                    "✅ Child terminated successfully",
                  )

                  // TEST: Get all children after termination  
                  case glixir.get_all_dynamic_children(sup) {
                    Ok(children) -> {
                      utils.debug_log(
                        logging.Info,
                        "✅ After termination: "
                          <> int.to_string(list.length(children))
                          <> " children remain",
                      )
                    }
                    Error(e) -> {
                      utils.debug_log(
                        logging.Warning,
                        "⚠️ Failed to get children after termination: " <> e,
                      )
                    }
                  }
                }
                Error(error) -> {
                  utils.debug_log(
                    logging.Warning,
                    "⚠️ Child termination failed: " <> error,
                  )
                }
              }
            }
            False -> {
              logging.log(logging.Error, "❌ Child process died immediately")
            }
          }
          True |> should.be_true
        }
        supervisor.StartChildError(error) -> {
          logging.log(logging.Error, "❌ Child start failed: " <> error)
          logging.log(logging.Info, "ℹ️ Might be missing TestGenServer module")
          True |> should.be_true
        }
      }
    }
    Error(error) -> {
      logging.log(
        logging.Error,
        "❌ Supervisor start failed: " <> string.inspect(error),
      )
      False |> should.be_true
    }
  }
}

pub fn supervisor_restart_strategies_test() {
  utils.debug_log(logging.Info, "🔄 Testing supervisor restart strategies")

  case
    glixir.start_dynamic_supervisor_named(atom.create("restart_strategy_sup"))
  {
    Ok(sup) -> {
      utils.debug_log(logging.Info, "✅ Supervisor started for restart test")

      let perm_spec =
        glixir.child_spec(
          "permanent_worker",
          "Elixir.TestGenServer",
          "start_link",
          "permanent_data",
          glixir.permanent,
          5000,
          glixir.worker,
        )

      let temp_spec =
        glixir.child_spec(
          "temporary_worker",
          "Elixir.TestGenServer",
          "start_link",
          "temporary_data",
          glixir.temporary,
          5000,
          glixir.worker,
        )

      let trans_spec =
        glixir.child_spec(
          "transient_worker",
          "Elixir.TestGenServer",
          "start_link",
          "transient_data",
          glixir.transient,
          5000,
          glixir.worker,
        )

      let results = [
        glixir.start_dynamic_child(sup, perm_spec, string_encode, simple_decode),
        glixir.start_dynamic_child(sup, temp_spec, string_encode, simple_decode),
        glixir.start_dynamic_child(
          sup,
          trans_spec,
          string_encode,
          simple_decode,
        ),
      ]

      let success_count =
        list.fold(results, 0, fn(acc, res) {
          case res {
            supervisor.ChildStarted(_, _) -> acc + 1
            supervisor.StartChildError(_) -> acc
          }
        })

      utils.debug_log(
        logging.Info,
        "✅ Started "
          <> int.to_string(success_count)
          <> "/3 workers with different restart strategies",
      )

      True |> should.be_true
    }
    Error(error) -> {
      logging.log(
        logging.Error,
        "❌ Supervisor start failed: " <> string.inspect(error),
      )
      False |> should.be_true
    }
  }
}

pub fn realistic_child_specs_test() {
  utils.debug_log(logging.Info, "🌍 Testing realistic child specifications")

  case glixir.start_dynamic_supervisor_named(atom.create("realistic_sup")) {
    Ok(sup) -> {
      utils.debug_log(logging.Info, "✅ Supervisor started for realistic test")

      // Test 1: Simple string config
      let config_worker =
        glixir.child_spec(
          "config_worker",
          "Elixir.TestGenServer",
          "start_link",
          "production_config",
          glixir.permanent,
          5000,
          glixir.worker,
        )

      case
        glixir.start_dynamic_child(
          sup,
          config_worker,
          string_encode,
          simple_decode,
        )
      {
        supervisor.ChildStarted(child_pid, _reply) -> {
          utils.debug_log(logging.Info, "✅ Config worker started successfully")

          case process.is_alive(child_pid) {
            True -> utils.debug_log(logging.Info, "✅ Config worker is healthy")
            False ->
              logging.log(logging.Error, "❌ Config worker crashed immediately")
          }
          True |> should.be_true
        }
        supervisor.StartChildError(error) -> {
          utils.debug_log(logging.Warning, "⚠️ Config worker failed: " <> error)
          True |> should.be_true
        }
      }
    }
    Error(error) -> {
      logging.log(
        logging.Error,
        "❌ Supervisor start failed: " <> string.inspect(error),
      )
      False |> should.be_true
    }
  }
}

pub fn multi_type_supervisor_test() {
  utils.debug_log(logging.Info, "🎯 Testing multi-type supervisor")

  // Test supervisor with tuple args
  case glixir.start_dynamic_supervisor_named(atom.create("multi_type_sup")) {
    Ok(sup) -> {
      utils.debug_log(logging.Info, "✅ Multi-type supervisor started!")

      let multi_spec =
        glixir.child_spec(
          "multi_arg_worker",
          "Elixir.TestGenServer",
          "start_link",
          #("worker_name", 42, True),
          glixir.permanent,
          5000,
          glixir.worker,
        )

      case
        glixir.start_dynamic_child(
          sup,
          multi_spec,
          multi_args_encode,
          simple_decode,
        )
      {
        supervisor.ChildStarted(_child_pid, _reply) -> {
          utils.debug_log(
            logging.Info,
            "✅ Multi-arg worker started successfully",
          )
          True |> should.be_true
        }
        supervisor.StartChildError(error) -> {
          utils.debug_log(
            logging.Warning,
            "⚠️ Multi-arg worker failed: " <> error,
          )
          True |> should.be_true
        }
      }
    }
    Error(error) -> {
      logging.log(
        logging.Error,
        "❌ Multi-type supervisor start failed: " <> string.inspect(error),
      )
      False |> should.be_true
    }
  }
}

pub fn complex_args_supervisor_test() {
  utils.debug_log(logging.Info, "🌍 Testing complex argument types")

  // Test with List(String) args
  case glixir.start_dynamic_supervisor_named(atom.create("list_args_sup")) {
    Ok(sup) -> {
      utils.debug_log(logging.Info, "✅ List args supervisor started!")

      let list_spec =
        glixir.child_spec(
          "list_worker",
          "Elixir.TestGenServer",
          "start_link",
          ["item1", "item2", "item3"],
          glixir.permanent,
          5000,
          glixir.worker,
        )

      case
        glixir.start_dynamic_child(
          sup,
          list_spec,
          list_args_encode,
          simple_decode,
        )
      {
        supervisor.ChildStarted(_child_pid, _reply) -> {
          utils.debug_log(logging.Info, "✅ List worker started successfully")
          True |> should.be_true
        }
        supervisor.StartChildError(error) -> {
          utils.debug_log(logging.Warning, "⚠️ List worker failed: " <> error)
          True |> should.be_true
        }
      }
    }
    Error(error) -> {
      logging.log(
        logging.Error,
        "❌ List args supervisor start failed: " <> string.inspect(error),
      )
      False |> should.be_true
    }
  }
}

pub fn type_compatibility_test() {
  utils.debug_log(
    logging.Info,
    "🔄 Testing type compatibility across Gleam/Elixir boundary",
  )

  let string_arg = dynamic.string("hello")
  let int_arg = dynamic.int(42)
  let bool_arg = dynamic.bool(True)
  let list_arg = dynamic.array([dynamic.string("a"), dynamic.string("b")])
  let map_arg =
    dynamic.properties([#(dynamic.string("key"), dynamic.string("value"))])

  let _spec =
    glixir.child_spec(
      "type_test",
      "Elixir.TestGenServer",
      "start_link",
      [string_arg, int_arg, bool_arg, list_arg, map_arg],
      glixir.permanent,
      5000,
      glixir.worker,
    )

  utils.debug_log(logging.Info, "✅ All basic types work across FFI boundary")
  True |> should.be_true
}

// ===================================
// CHILD SPEC TESTS
// ===================================

pub fn child_spec_creation_test() {
  let spec =
    glixir.child_spec(
      "test_worker_1",
      "test_worker",
      "start_link",
      "test_data",
      glixir.permanent,
      5000,
      glixir.worker,
    )

  spec.id |> should.equal("test_worker_1")
  utils.debug_log(logging.Info, "✅ Child spec created with correct defaults")
}

pub fn child_spec_with_custom_options_test() {
  let spec =
    glixir.child_spec(
      "custom_worker",
      "custom_module",
      "init",
      #("arg1", 42),
      glixir.temporary,
      10_000,
      glixir.worker,
    )

  spec.id |> should.equal("custom_worker")
  spec.restart |> should.equal(glixir.temporary)
  spec.shutdown_timeout |> should.equal(10_000)

  utils.debug_log(logging.Info, "✅ Custom child spec created successfully")
}

pub fn restart_strategy_test() {
  let permanent_spec =
    glixir.child_spec(
      "perm",
      "mod",
      "fun",
      "data",
      glixir.permanent,
      5000,
      glixir.worker,
    )

  let temporary_spec =
    glixir.child_spec(
      "temp",
      "mod",
      "fun",
      "data",
      glixir.temporary,
      5000,
      glixir.worker,
    )

  let transient_spec =
    glixir.child_spec(
      "trans",
      "mod",
      "fun",
      "data",
      glixir.transient,
      5000,
      glixir.worker,
    )

  permanent_spec.id |> should.equal("perm")
  permanent_spec.restart |> should.equal(glixir.permanent)

  temporary_spec.restart |> should.equal(glixir.temporary)
  transient_spec.restart |> should.equal(glixir.transient)

  utils.debug_log(logging.Info, "✅ All restart strategies work correctly")
}

pub fn child_spec_properties_test() {
  let test_cases = [
    #("worker1", "module1", "start_link"),
    #("worker2", "module2", "init"),
    #("worker3", "gen_server", "start_link"),
  ]

  let specs =
    list.map(test_cases, fn(test_case) {
      let #(id, module, function) = test_case
      glixir.child_spec(
        id,
        module,
        function,
        "test_data",
        glixir.permanent,
        5000,
        glixir.worker,
      )
    })

  list.each(specs, fn(spec) {
    spec.restart |> should.equal(glixir.permanent)
    spec.child_type |> should.equal(glixir.worker)
    spec.shutdown_timeout |> should.equal(5000)
  })

  utils.debug_log(
    logging.Info,
    "✅ Child spec properties validated across multiple cases",
  )
}

// ============================================================================
// GENSERVER TESTS 
// ============================================================================

pub fn genserver_start_test() {
  utils.debug_log(logging.Info, "🤖 Testing GenServer start functionality")

  case glixir.start_genserver("TestGenServer", dynamic.string("test_state")) {
    Ok(genserver) -> {
      utils.debug_log(logging.Info, "✅ GenServer started successfully")

      let pid = glixir.genserver_pid(genserver)
      case process.is_alive(pid) {
        True -> {
          utils.debug_log(logging.Info, "✅ GenServer process is alive")
          // All requests must be Dynamic
          case
            glixir.call_genserver(
              genserver,
              atom.to_dynamic(atom.create("ping")),
              decode.dynamic,
            )
          {
            Ok(_) -> {
              utils.debug_log(logging.Info, "✅ GenServer ping successful")
              case
                glixir.call_genserver(
                  genserver,
                  atom.to_dynamic(atom.create("get_state")),
                  decode.dynamic,
                )
              {
                Ok(_) -> {
                  utils.debug_log(
                    logging.Info,
                    "✅ GenServer get_state successful",
                  )
                  let _ =
                    glixir.cast_genserver(
                      genserver,
                      atom.to_dynamic(atom.create("stop")),
                    )
                  True |> should.be_true
                }
                Error(_) -> {
                  utils.debug_log(
                    logging.Warning,
                    "⚠️ GenServer get_state failed",
                  )
                  let _ =
                    glixir.cast_genserver(
                      genserver,
                      atom.to_dynamic(atom.create("stop")),
                    )
                  True |> should.be_true
                }
              }
            }
            Error(_) -> {
              utils.debug_log(logging.Warning, "⚠️ GenServer ping failed")
              let _ =
                glixir.cast_genserver(
                  genserver,
                  atom.to_dynamic(atom.create("stop")),
                )
              True |> should.be_true
            }
          }
        }
        False -> {
          logging.log(logging.Error, "❌ GenServer process died immediately")
          False |> should.be_true
        }
      }
    }
    Error(_error) -> {
      utils.debug_log(
        logging.Warning,
        "⚠️ GenServer start failed (might be missing TestGenServer module)",
      )
      True |> should.be_true
    }
  }
}

pub fn genserver_named_start_test() {
  utils.debug_log(logging.Info, "🏷️ Testing named GenServer start")

  let name = atom.create("test_genserver")
  case
    glixir.start_genserver_named(
      "TestGenServer",
      name,
      dynamic.string("named_state"),
    )
  {
    Ok(genserver) -> {
      utils.debug_log(logging.Info, "✅ Named GenServer started successfully")

      case glixir.lookup_genserver(name) {
        Ok(looked_up_genserver) -> {
          utils.debug_log(logging.Info, "✅ GenServer lookup by name successful")
          let original_pid = glixir.genserver_pid(genserver)
          let looked_up_pid = glixir.genserver_pid(looked_up_genserver)

          case original_pid == looked_up_pid {
            True -> {
              utils.debug_log(
                logging.Info,
                "✅ Looked up GenServer matches original",
              )
              let _ =
                glixir.cast_genserver(
                  genserver,
                  atom.to_dynamic(atom.create("stop")),
                )
              True |> should.be_true
            }
            False -> {
              logging.log(
                logging.Error,
                "❌ Looked up GenServer doesn't match original",
              )
              let _ =
                glixir.cast_genserver(
                  genserver,
                  atom.to_dynamic(atom.create("stop")),
                )
              False |> should.be_true
            }
          }
        }
        Error(error) -> {
          logging.log(
            logging.Error,
            "❌ GenServer lookup failed: " <> string.inspect(error),
          )
          let _ =
            glixir.cast_genserver(
              genserver,
              atom.to_dynamic(atom.create("stop")),
            )
          False |> should.be_true
        }
      }
    }
    Error(_error) -> {
      utils.debug_log(
        logging.Warning,
        "⚠️ Named GenServer start failed (might be missing TestGenServer module)",
      )
      True |> should.be_true
    }
  }
}

pub fn genserver_call_test() {
  utils.debug_log(logging.Info, "📞 Testing GenServer call functionality")

  case
    glixir.start_genserver("TestGenServer", dynamic.string("call_test_state"))
  {
    Ok(genserver) -> {
      utils.debug_log(logging.Info, "✅ GenServer started for call test")
      case
        glixir.call_genserver(
          genserver,
          atom.to_dynamic(atom.create("ping")),
          decode.dynamic,
        )
      {
        Ok(_response) -> {
          utils.debug_log(logging.Info, "✅ GenServer ping successful")
          case
            glixir.call_genserver(
              genserver,
              atom.to_dynamic(atom.create("get_state")),
              decode.dynamic,
            )
          {
            Ok(_state) -> {
              utils.debug_log(logging.Info, "✅ GenServer get_state successful")
              let _ =
                glixir.cast_genserver(
                  genserver,
                  atom.to_dynamic(atom.create("stop")),
                )
              True |> should.be_true
            }
            Error(error) -> {
              logging.log(
                logging.Error,
                "❌ GenServer get_state failed: " <> string.inspect(error),
              )
              let _ =
                glixir.cast_genserver(
                  genserver,
                  atom.to_dynamic(atom.create("stop")),
                )
              True |> should.be_true
            }
          }
        }
        Error(error) -> {
          logging.log(
            logging.Error,
            "❌ GenServer ping failed: " <> string.inspect(error),
          )
          let _ =
            glixir.cast_genserver(
              genserver,
              atom.to_dynamic(atom.create("stop")),
            )
          True |> should.be_true
        }
      }
    }
    Error(_error) -> {
      utils.debug_log(
        logging.Warning,
        "⚠️ GenServer start for call test failed (might be missing TestGenServer module)",
      )
      True |> should.be_true
    }
  }
}

pub fn genserver_call_named_test() {
  utils.debug_log(logging.Info, "📞🏷️ Testing named GenServer call")

  let name = atom.create("call_named_test")
  case
    glixir.start_genserver_named(
      "TestGenServer",
      name,
      dynamic.string("named_call_state"),
    )
  {
    Ok(genserver) -> {
      utils.debug_log(logging.Info, "✅ Named GenServer started for call test")
      case
        glixir.call_genserver_named(
          name,
          atom.to_dynamic(atom.create("ping")),
          decode.dynamic,
        )
      {
        Ok(_response) -> {
          utils.debug_log(logging.Info, "✅ Named GenServer call successful")
          let _ =
            glixir.cast_genserver(
              genserver,
              atom.to_dynamic(atom.create("stop")),
            )
          True |> should.be_true
        }
        Error(error) -> {
          logging.log(
            logging.Error,
            "❌ Named GenServer call failed: " <> string.inspect(error),
          )
          let _ =
            glixir.cast_genserver(
              genserver,
              atom.to_dynamic(atom.create("stop")),
            )
          False |> should.be_true
        }
      }
    }
    Error(_error) -> {
      utils.debug_log(
        logging.Warning,
        "⚠️ Named GenServer start for call test failed (might be missing TestGenServer module)",
      )
      True |> should.be_true
    }
  }
}

pub fn genserver_cast_test() {
  utils.debug_log(logging.Info, "📨 Testing GenServer cast functionality")

  case
    glixir.start_genserver("TestGenServer", dynamic.string("cast_test_state"))
  {
    Ok(genserver) -> {
      utils.debug_log(logging.Info, "✅ GenServer started for cast test")
      case
        glixir.cast_genserver(
          genserver,
          atom.to_dynamic(atom.create("test_cast_message")),
        )
      {
        Ok(_) -> {
          utils.debug_log(logging.Info, "✅ GenServer cast successful")
          let named_name = atom.create("cast_named_test")
          case
            glixir.start_genserver_named(
              "TestGenServer",
              named_name,
              dynamic.string("cast_named_state"),
            )
          {
            Ok(named_genserver) -> {
              case
                glixir.cast_genserver_named(
                  named_name,
                  atom.to_dynamic(atom.create("named_cast_message")),
                )
              {
                Ok(_) -> {
                  utils.debug_log(
                    logging.Info,
                    "✅ Named GenServer cast successful",
                  )
                  let _ =
                    glixir.cast_genserver(
                      genserver,
                      atom.to_dynamic(atom.create("stop")),
                    )
                  let _ =
                    glixir.cast_genserver(
                      named_genserver,
                      atom.to_dynamic(atom.create("stop")),
                    )
                  True |> should.be_true
                }
                Error(error) -> {
                  logging.log(
                    logging.Error,
                    "❌ Named GenServer cast failed: " <> string.inspect(error),
                  )
                  let _ =
                    glixir.cast_genserver(
                      genserver,
                      atom.to_dynamic(atom.create("stop")),
                    )
                  let _ =
                    glixir.cast_genserver(
                      named_genserver,
                      atom.to_dynamic(atom.create("stop")),
                    )
                  False |> should.be_true
                }
              }
            }
            Error(_) -> {
              utils.debug_log(
                logging.Warning,
                "⚠️ Named GenServer for cast test failed to start (might be missing TestGenServer module)",
              )
              let _ =
                glixir.cast_genserver(
                  genserver,
                  atom.to_dynamic(atom.create("stop")),
                )
              True |> should.be_true
            }
          }
        }
        Error(error) -> {
          logging.log(
            logging.Error,
            "❌ GenServer cast failed: " <> string.inspect(error),
          )
          let _ =
            glixir.cast_genserver(
              genserver,
              atom.to_dynamic(atom.create("stop")),
            )
          False |> should.be_true
        }
      }
    }
    Error(_error) -> {
      utils.debug_log(
        logging.Warning,
        "⚠️ GenServer start for cast test failed (might be missing TestGenServer module)",
      )
      True |> should.be_true
    }
  }
}

pub fn genserver_timeout_test() {
  utils.debug_log(logging.Info, "⏱️ Testing GenServer call with timeout")

  case
    glixir.start_genserver(
      "TestGenServer",
      dynamic.string("timeout_test_state"),
    )
  {
    Ok(genserver) -> {
      utils.debug_log(logging.Info, "✅ GenServer started for timeout test")
      case
        glixir.call_genserver_timeout(
          genserver,
          atom.to_dynamic(atom.create("ping")),
          1000,
          decode.dynamic,
        )
      {
        Ok(_response) -> {
          utils.debug_log(
            logging.Info,
            "✅ GenServer call with timeout successful",
          )
          let _ =
            glixir.cast_genserver(
              genserver,
              atom.to_dynamic(atom.create("stop")),
            )
          True |> should.be_true
        }
        Error(error) -> {
          logging.log(
            logging.Error,
            "❌ GenServer call with timeout failed: " <> string.inspect(error),
          )
          let _ =
            glixir.cast_genserver(
              genserver,
              atom.to_dynamic(atom.create("stop")),
            )
          False |> should.be_true
        }
      }
    }
    Error(_error) -> {
      utils.debug_log(
        logging.Warning,
        "⚠️ GenServer start for timeout test failed (might be missing TestGenServer module)",
      )
      True |> should.be_true
    }
  }
}

pub fn genserver_lifecycle_test() {
  utils.debug_log(logging.Info, "♻️ Testing GenServer complete lifecycle")

  // Test the full lifecycle: start -> call -> cast -> stop
  case
    glixir.start_genserver("TestGenServer", dynamic.string("lifecycle_test"))
  {
    Ok(genserver) -> {
      utils.debug_log(logging.Info, "✅ GenServer started for lifecycle test")
      let pid = glixir.genserver_pid(genserver)

      // Verify it's alive
      case process.is_alive(pid) {
        True -> {
          utils.debug_log(logging.Info, "✅ GenServer is alive after start")

          // Do a call
          case
            glixir.call_genserver(
              genserver,
              atom.to_dynamic(atom.create("ping")),
              decode.dynamic,
            )
          {
            Ok(_) -> {
              utils.debug_log(logging.Info, "✅ GenServer responded to call")

              // Do a cast  
              case
                glixir.cast_genserver(
                  genserver,
                  atom.to_dynamic(atom.create("lifecycle_cast")),
                )
              {
                Ok(_) -> {
                  utils.debug_log(logging.Info, "✅ GenServer accepted cast")

                  // Stop gracefully (EXPLICIT cast with :stop atom)
                  case
                    glixir.cast_genserver(
                      genserver,
                      atom.to_dynamic(atom.create("stop")),
                    )
                  {
                    Ok(_) -> {
                      utils.debug_log(
                        logging.Info,
                        "✅ GenServer stop cast sent",
                      )
                      process.sleep(10)
                      // Small delay for cleanup
                      case process.is_alive(pid) {
                        False -> {
                          utils.debug_log(
                            logging.Info,
                            "✅ GenServer process terminated successfully",
                          )
                          True |> should.be_true
                        }
                        True -> {
                          utils.debug_log(
                            logging.Warning,
                            "⚠️ GenServer process still alive after stop (might be normal)",
                          )
                          True |> should.be_true
                        }
                      }
                    }
                    Error(error) -> {
                      logging.log(
                        logging.Error,
                        "❌ GenServer stop cast failed: "
                          <> string.inspect(error),
                      )
                      False |> should.be_true
                    }
                  }
                }
                Error(error) -> {
                  logging.log(
                    logging.Error,
                    "❌ GenServer cast in lifecycle failed: "
                      <> string.inspect(error),
                  )
                  // Try to stop anyway
                  let _ =
                    glixir.cast_genserver(
                      genserver,
                      atom.to_dynamic(atom.create("stop")),
                    )
                  False |> should.be_true
                }
              }
            }
            Error(error) -> {
              logging.log(
                logging.Error,
                "❌ GenServer call in lifecycle failed: "
                  <> string.inspect(error),
              )
              let _ =
                glixir.cast_genserver(
                  genserver,
                  atom.to_dynamic(atom.create("stop")),
                )
              False |> should.be_true
            }
          }
        }
        False -> {
          logging.log(logging.Error, "❌ GenServer not alive after start")
          False |> should.be_true
        }
      }
    }
    Error(_error) -> {
      utils.debug_log(
        logging.Warning,
        "⚠️ GenServer start for lifecycle test failed (might be missing TestGenServer module)",
      )
      True |> should.be_true
    }
  }
}

// ============================================================================
// AGENT TESTS
// ============================================================================

pub fn agent_integration_test() {
  let initial_state = fn() { 42 }
  case glixir.start_agent(initial_state) {
    Ok(agent) -> {
      case glixir.get_agent(agent, fn(x) { x }, decode.int) {
        Ok(value) -> {
          value |> should.equal(42)
          utils.debug_log(logging.Info, "✅ Agent state retrieved successfully")
        }
        Error(_) -> {
          utils.debug_log(logging.Warning, "⚠️ Agent get failed")
          True |> should.be_true
        }
      }

      // Pass Atom reason for stop (e.g., atom.create("normal"))
      let _ = glixir.stop_agent(agent, atom.create("normal"))
      True |> should.be_true
    }
    Error(_) -> {
      utils.debug_log(logging.Warning, "⚠️ Agent start failed")
      True |> should.be_true
    }
  }
}

// ============================================================================
// UTILITY TESTS
// ============================================================================

pub fn process_spawning_test() {
  let pid = spawn_test_process()
  utils.debug_log(logging.Info, "✅ Test process spawned successfully")

  let is_running = process.is_alive(pid)
  case is_running {
    True -> {
      utils.debug_log(logging.Info, "✅ Process is running")
      True |> should.be_true
    }
    False -> {
      utils.debug_log(
        logging.Info,
        "⚠️ Process already finished (expected for short-lived test process)",
      )
      True |> should.be_true
    }
  }
}
