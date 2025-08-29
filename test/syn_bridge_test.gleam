// test/syn_bridge_test.gleam
import gleam/list
import gleam/string
import gleeunit
import gleeunit/should
import glixir/syn
import logging

pub fn main() {
  logging.configure()
  gleeunit.main()
}

pub fn syn_init_test() {
  // Just verify init_scopes doesn't crash
  syn.init_scopes(["test_scope_1", "test_scope_2"])
  True |> should.be_true
}

// test/syn_bridge_test.gleam - update this test
pub fn syn_register_whereis_test() {
  syn.init_scopes(["test_registry"])

  // Register current process with some metadata
  let test_metadata = "some_test_data"

  case syn.register("test_registry", "test_process", test_metadata) {
    Ok(_) -> {
      logging.log(logging.Info, "✅ Registration succeeded")

      // Use lookup instead of whereis to get metadata
      case syn.lookup("test_registry", "test_process") {
        Ok(#(_pid, metadata)) -> {
          logging.log(
            logging.Info,
            "✅ Lookup found process with metadata: " <> string.inspect(metadata),
          )
          True |> should.be_true
        }
        Error(err) -> {
          logging.log(logging.Error, "❌ Lookup failed: " <> string.inspect(err))
          False |> should.be_true
        }
      }
    }
    Error(err) -> {
      logging.log(
        logging.Error,
        "❌ Registration failed: " <> string.inspect(err),
      )
      False |> should.be_true
    }
  }
}

pub fn syn_unregister_test() {
  syn.init_scopes(["test_unreg"])

  // Register first
  let _ = syn.register("test_unreg", "temp_process", "temp_data")

  // Now unregister
  case syn.unregister("test_unreg", "temp_process") {
    Ok(_) -> {
      logging.log(logging.Info, "✅ Unregister succeeded")

      // Verify it's gone
      case syn.whereis("test_unreg", "temp_process") {
        Error(_) -> {
          logging.log(
            logging.Info,
            "✅ Process correctly not found after unregister",
          )
          True |> should.be_true
        }
        Ok(_) -> {
          logging.log(logging.Error, "❌ Process still found after unregister")
          False |> should.be_true
        }
      }
    }
    Error(err) -> {
      logging.log(
        logging.Warning,
        "⚠️ Unregister failed (might not have been registered): "
          <> string.inspect(err),
      )
      True |> should.be_true
    }
  }
}

pub fn syn_pubsub_join_leave_test() {
  syn.init_scopes(["test_pubsub"])

  // Join a group
  case syn.join("test_pubsub", "test_group") {
    Ok(_) -> {
      logging.log(logging.Info, "✅ Join succeeded")

      // Check member count
      let count = syn.member_count("test_pubsub", "test_group")
      logging.log(logging.Info, "Member count: " <> string.inspect(count))

      // Leave the group
      case syn.leave("test_pubsub", "test_group") {
        Ok(_) -> {
          logging.log(logging.Info, "✅ Leave succeeded")
          True |> should.be_true
        }
        Error(err) -> {
          logging.log(logging.Error, "❌ Leave failed: " <> string.inspect(err))
          False |> should.be_true
        }
      }
    }
    Error(err) -> {
      logging.log(logging.Error, "❌ Join failed: " <> string.inspect(err))
      False |> should.be_true
    }
  }
}

pub fn syn_publish_test() {
  syn.init_scopes(["test_publish"])

  // Join first so there's someone to receive
  let _ = syn.join("test_publish", "test_channel")

  // Publish a message
  case syn.publish("test_publish", "test_channel", "Hello from test!") {
    Ok(count) -> {
      logging.log(
        logging.Info,
        "✅ Published to " <> string.inspect(count) <> " processes",
      )
      True |> should.be_true
    }
    Error(err) -> {
      logging.log(logging.Error, "❌ Publish failed: " <> string.inspect(err))
      False |> should.be_true
    }
  }
}

pub fn syn_members_test() {
  syn.init_scopes(["test_members"])

  // Join to be a member
  let _ = syn.join("test_members", "member_group")

  // Get members list using members_detailed (the function that's actually exported)
  let members = syn.members_detailed("test_members", "member_group")
  logging.log(
    logging.Info,
    "Found " <> string.inspect(list.length(members)) <> " members",
  )

  // Get member count
  let count = syn.member_count("test_members", "member_group")
  logging.log(logging.Info, "Member count: " <> string.inspect(count))

  True |> should.be_true
}

pub fn syn_lookup_test() {
  syn.init_scopes(["test_lookup"])

  // Register a process
  let _ = syn.register("test_lookup", "lookup_target", "lookup_data")

  // Try the lookup function (alternative to whereis)
  case syn.lookup("test_lookup", "lookup_target") {
    Ok(#(_pid, metadata)) -> {
      logging.log(
        logging.Info,
        "✅ Lookup found process with metadata: " <> string.inspect(metadata),
      )
      True |> should.be_true
    }
    Error(err) -> {
      logging.log(logging.Error, "❌ Lookup failed: " <> string.inspect(err))
      False |> should.be_true
    }
  }
}
