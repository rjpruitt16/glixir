// Dynamic Worker Pool Example
// Shows how to build a dynamic worker pool using glixir's DynamicSupervisor

import gleam/dynamic
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import glixir

pub fn main() {
  io.println("🚀 Starting Dynamic Worker Pool Example")

  case start_worker_pool() {
    Ok(supervisor) -> {
      io.println("✅ Worker pool started successfully!")

      // Add more workers dynamically
      let _ = scale_up_workers(supervisor, 3)

      // Show pool status
      show_pool_status(supervisor)

      // Simulate some work
      simulate_work(supervisor)
    }
    Error(reason) -> {
      io.println("❌ Failed to start worker pool: " <> reason)
    }
  }
}

/// Start a dynamic worker pool supervisor
fn start_worker_pool() -> Result(glixir.Supervisor, String) {
  case glixir.start_supervisor_named("worker_pool", []) {
    Ok(supervisor) -> {
      io.println("📦 Worker pool supervisor started")

      // Start initial workers
      case start_initial_workers(supervisor, 2) {
        Ok(_) -> Ok(supervisor)
        Error(err) -> Error("Failed to start initial workers: " <> err)
      }
    }
    Error(_) -> Error("Failed to start supervisor")
  }
}

/// Start initial set of workers
fn start_initial_workers(
  supervisor: glixir.Supervisor,
  count: Int,
) -> Result(Nil, String) {
  list.range(1, count)
  |> list.try_each(fn(i) {
    let worker_spec =
      glixir.child_spec(
        id: "worker_" <> int.to_string(i),
        module: "MyApp.Worker",
        function: "start_link",
        args: [dynamic.string("config_" <> int.to_string(i))],
      )

    case glixir.start_child(supervisor, worker_spec) {
      Ok(_pid) -> {
        io.println("👷 Started worker_" <> int.to_string(i))
        Ok(Nil)
      }
      Error(reason) -> {
        io.println(
          "⚠️  Failed to start worker_" <> int.to_string(i) <> ": " <> reason,
        )
        Error(reason)
      }
    }
  })
}

/// Scale up the worker pool by adding more workers
fn scale_up_workers(supervisor: glixir.Supervisor, additional_count: Int) -> Nil {
  io.println("📈 Scaling up worker pool...")

  // Get current worker count (simplified - in real app you'd track this)
  let current_count = 2
  let start_index = current_count + 1
  let end_index = current_count + additional_count

  list.range(start_index, end_index)
  |> list.each(fn(i) {
    let worker_spec =
      glixir.child_spec(
        id: "worker_" <> int.to_string(i),
        module: "MyApp.Worker",
        function: "start_link",
        args: [dynamic.string("config_" <> int.to_string(i))],
      )

    case glixir.start_child(supervisor, worker_spec) {
      Ok(_pid) -> io.println("🆕 Added worker_" <> int.to_string(i))
      Error(reason) ->
        io.println(
          "❌ Failed to add worker_" <> int.to_string(i) <> ": " <> reason,
        )
    }
  })
}

/// Show current pool status
fn show_pool_status(supervisor: glixir.Supervisor) -> Nil {
  io.println("\n📊 Current Pool Status:")

  let children = glixir.which_children(supervisor)
  io.println("👥 Active workers: " <> int.to_string(list.length(children)))

  let counts = glixir.count_children(supervisor)
  case counts {
    glixir.ChildCounts(specs, active, supervisors, workers) -> {
      io.println("📋 Specs: " <> int.to_string(specs))
      io.println("🟢 Active: " <> int.to_string(active))
      io.println("👷 Workers: " <> int.to_string(workers))
      io.println("👨‍💼 Supervisors: " <> int.to_string(supervisors))
    }
  }

  io.println("")
}

/// Simulate work being distributed to workers
fn simulate_work(supervisor: glixir.Supervisor) -> Nil {
  io.println("💼 Simulating work distribution...")

  let children = glixir.which_children(supervisor)

  children
  |> list.each(fn(child_info) {
    case child_info {
      glixir.ChildInfo(id, glixir.ChildPid(pid), _, _) -> {
        io.println(
          "📨 Sending work to "
          <> dynamic.string(id)
          <> " (PID: "
          <> string.inspect(pid)
          <> ")",
        )
        // In a real app, you'd send actual work messages to the worker PIDs
        // glixir.cast_genserver(pid, work_message)
      }
      glixir.ChildInfo(id, status, _, _) -> {
        io.println(
          "⚠️  Worker "
          <> dynamic.string(id)
          <> " is not available: "
          <> string.inspect(status),
        )
      }
    }
  })
}

/// Example worker fault tolerance
pub fn demonstrate_fault_tolerance() {
  io.println("\n🛡️  Demonstrating Fault Tolerance")

  case glixir.start_supervisor_named("fault_tolerance_demo", []) {
    Ok(supervisor) -> {
      // Start a worker with permanent restart (will always restart)
      let permanent_spec =
        glixir.SimpleChildSpec(
          ..glixir.child_spec(
            "critical_worker",
            "MyApp.CriticalWorker",
            "start_link",
            [],
          ),
          restart: glixir.permanent,
        )

      // Start a worker with temporary restart (won't restart)
      let temporary_spec =
        glixir.SimpleChildSpec(
          ..glixir.child_spec(
            "temp_worker",
            "MyApp.TempWorker",
            "start_link",
            [],
          ),
          restart: glixir.temporary,
        )

      case glixir.start_child(supervisor, permanent_spec) {
        Ok(_) -> io.println("✅ Critical worker started (permanent restart)")
        Error(e) -> io.println("❌ Failed to start critical worker: " <> e)
      }

      case glixir.start_child(supervisor, temporary_spec) {
        Ok(_) -> io.println("✅ Temp worker started (temporary restart)")
        Error(e) -> io.println("❌ Failed to start temp worker: " <> e)
      }

      io.println("💡 If workers crash:")
      io.println("   - Critical worker will automatically restart")
      io.println("   - Temp worker will NOT restart")
    }
    Error(_) -> io.println("❌ Failed to start fault tolerance demo")
  }
}

/// Advanced: Custom shutdown timeouts and child types
pub fn demonstrate_advanced_specs() {
  io.println("\n⚙️  Advanced Child Specifications")

  case glixir.start_supervisor_named("advanced_demo", []) {
    Ok(supervisor) -> {
      // Worker with custom shutdown timeout
      let custom_worker =
        glixir.SimpleChildSpec(
          id: "custom_worker",
          start_module: atom.create("MyApp.CustomWorker"),
          start_function: atom.create("start_link"),
          start_args: [dynamic.string("custom_config")],
          restart: glixir.permanent,
          shutdown_timeout: 10_000,
          // 10 seconds to shutdown gracefully
          child_type: glixir.worker,
        )

      // Nested supervisor as a child
      let nested_supervisor =
        glixir.SimpleChildSpec(
          id: "nested_supervisor",
          start_module: atom.create("MyApp.NestedSupervisor"),
          start_function: atom.create("start_link"),
          start_args: [dynamic.array([])],
          restart: glixir.permanent,
          shutdown_timeout: 15_000,
          // More time for supervisor shutdown
          child_type: glixir.supervisor_child,
        )

      case glixir.start_child(supervisor, custom_worker) {
        Ok(_) -> io.println("✅ Custom worker started with 10s shutdown timeout")
        Error(e) -> io.println("❌ Custom worker failed: " <> e)
      }

      case glixir.start_child(supervisor, nested_supervisor) {
        Ok(_) -> io.println("✅ Nested supervisor started")
        Error(e) -> io.println("❌ Nested supervisor failed: " <> e)
      }
    }
    Error(_) -> io.println("❌ Failed to start advanced demo")
  }
}
