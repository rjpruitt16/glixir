defmodule Glixir.Supervisor do
  @moduledoc """
  Elixir wrapper for OTP Supervisor functions that converts responses
  into Gleam-compatible tuple formats.
  """

  # Use Gleam utils module for debug logging (updated path)
  defp debug_log(level, message) do
    :glixir@utils.debug_log(level, message)
  end
  
  # Always log (for critical errors) (updated path)
  defp always_log(level, message) do
    :glixir@utils.always_log(level, message)
  end  

  # ========================================
  # DYNAMIC SUPERVISOR FUNCTIONS
  # ========================================

  @doc """
  Start a DynamicSupervisor with options provided as a string-to-string map.

  Options map can contain:
  - "name" - supervisor name
  - "strategy" - "one_for_one" (default)
  - "max_restarts" - string number (default "3")
  - "max_seconds" - string number (default "5")

  Returns:
  - {:dynamic_supervisor_ok, pid} for successful start
  - {:dynamic_supervisor_error, reason} for errors
  """
  def start_dynamic_supervisor(options_map) when is_map(options_map) do
    debug_log(:debug, "Starting DynamicSupervisor with options: #{inspect(options_map)}")

    # Convert string map to keyword list with proper atoms
    opts =
      options_map
      |> Enum.reduce([], fn
        {"name", name}, acc ->
          [{:name, String.to_atom(name)} | acc]

        {"strategy", strategy}, acc ->
          [{:strategy, String.to_atom(strategy)} | acc]

        {"max_restarts", max_restarts}, acc ->
          [{:max_restarts, String.to_integer(max_restarts)} | acc]

        {"max_seconds", max_seconds}, acc ->
          [{:max_seconds, String.to_integer(max_seconds)} | acc]

        {_key, _value}, acc ->
          # Ignore unknown options
          acc
      end)
      |> Enum.reverse()

    # Add default strategy if not provided
    opts =
      if Keyword.has_key?(opts, :strategy), do: opts, else: [{:strategy, :one_for_one} | opts]

    case DynamicSupervisor.start_link(opts) do
      {:ok, pid} ->
        debug_log(:info, "DynamicSupervisor started successfully: #{inspect(pid)}")
        {:dynamic_supervisor_ok, pid}

      {:error, {:already_started, pid}} ->
        debug_log(:debug, "DynamicSupervisor already started: #{inspect(pid)}")
        {:dynamic_supervisor_ok, pid}

      {:error, reason} ->
        always_log(:error, "DynamicSupervisor start failed: #{inspect(reason)}")
        {:dynamic_supervisor_error, reason}
    end
  end

  @doc """
  Start a named DynamicSupervisor with just a name (uses defaults).
  """
  def start_dynamic_supervisor_named(name) when is_binary(name) do
    debug_log(:debug, "Starting named DynamicSupervisor: #{name}")
    start_dynamic_supervisor(%{"name" => name})
  end

  @doc """
  Start a DynamicSupervisor with default options.
  """
  def start_dynamic_supervisor_simple() do
    debug_log(:debug, "Starting simple DynamicSupervisor")
    start_dynamic_supervisor(%{})
  end

  @doc """
  Start a child in a DynamicSupervisor using a spec map.

  Spec map should contain:
  - "id" - child identifier
  - "start_module" - module name as string
  - "start_function" - function name as string  
  - "start_args" - list of arguments
  - "restart" - "permanent", "temporary", or "transient"
  - "shutdown" - shutdown timeout as string number
  - "type" - "worker" or "supervisor"

  Returns:
  - {:dynamic_start_child_ok, pid} for successful start
  - {:dynamic_start_child_error, reason} for errors
  """
  def start_dynamic_child(supervisor, spec_map) when is_map(spec_map) do
    child_id = Map.get(spec_map, "id", "unknown")
    debug_log(:debug, "Starting dynamic child: #{child_id}")

    # Safely convert module and function names to atoms
    module_name = Map.get(spec_map, "start_module")
    function_name = Map.get(spec_map, "start_function")

    # Use String.to_atom instead of String.to_existing_atom for more flexibility
    module_atom = String.to_atom(module_name)
    function_atom = String.to_atom(function_name)

    debug_log(:debug, "Converted module: #{inspect(module_atom)}, function: #{inspect(function_atom)}")

    # Get the arguments - this is the critical fix!
    args = Map.get(spec_map, "start_args", [])

    # IMPORTANT: Ensure args is always a list, never a tuple
    args_list =
      case args do
        # If it's already a list, use it as-is
        list when is_list(list) -> list
        # If it's a tuple, convert to list
        tuple when is_tuple(tuple) -> Tuple.to_list(tuple)
        # If it's a single value, wrap in a list
        single_value -> [single_value]
      end

    child_spec = %{
      id: Map.get(spec_map, "id"),
      start: {
        module_atom,
        function_atom,
        args_list
      },
      restart: String.to_atom(Map.get(spec_map, "restart", "permanent")),
      shutdown: String.to_integer(Map.get(spec_map, "shutdown", "5000")),
      type: String.to_atom(Map.get(spec_map, "type", "worker"))
    }

    debug_log(:debug, "Starting child with spec: #{inspect(child_spec)}")

    case DynamicSupervisor.start_child(supervisor, child_spec) do
      {:ok, pid} ->
        debug_log(:info, "Dynamic child '#{child_id}' started successfully: #{inspect(pid)}")
        {:dynamic_start_child_ok, pid}

      {:ok, pid, _info} ->
        debug_log(:info, "Dynamic child '#{child_id}' started with info: #{inspect(pid)}")
        {:dynamic_start_child_ok, pid}

      {:error, {:already_started, pid}} ->
        debug_log(:debug, "Dynamic child '#{child_id}' already started: #{inspect(pid)}")
        {:dynamic_start_child_ok, pid}

      {:error, reason} ->
        always_log(:error, "Dynamic child '#{child_id}' start failed: #{inspect(reason)}")
        {:dynamic_start_child_error, reason}
    end
  end

  @doc """
  Terminate a child in a DynamicSupervisor.

  Returns:
  - {:dynamic_terminate_child_ok} for :ok
  - {:dynamic_terminate_child_error, reason} for errors
  """
  def terminate_dynamic_child(supervisor_pid, child_pid) do
    debug_log(:debug, "terminate_dynamic_child called with supervisor: #{inspect(supervisor_pid)}, child: #{inspect(child_pid)}")

    result = DynamicSupervisor.terminate_child(supervisor_pid, child_pid)
    debug_log(:debug, "DynamicSupervisor.terminate_child returned: #{inspect(result)}")

    case result do
      :ok ->
        debug_log(:info, "Child terminated successfully")
        {:dynamic_terminate_child_ok}

      {:error, reason} ->
        always_log(:error, "Child termination failed: #{inspect(reason)}")
        {:dynamic_terminate_child_error, reason}
    end
  end

  @doc """
  Get information about all children in a DynamicSupervisor.

  Returns list of: {:child_info, id, child_status, child_type, modules}
  """
  def which_dynamic_children(supervisor) do
    debug_log(:debug, "Querying dynamic children for supervisor: #{inspect(supervisor)}")

    children = DynamicSupervisor.which_children(supervisor)
    debug_log(:debug, "Found #{length(children)} dynamic children")

    children
    |> Enum.map(fn {id, child, type, modules} ->
      child_status =
        case child do
          pid when is_pid(pid) -> {:child_pid, pid}
          :restarting -> {:child_restarting}
          :undefined -> {:child_undefined}
        end

      child_type =
        case type do
          :worker -> {:worker}
          :supervisor -> {:supervisor_child}
        end

      child_modules =
        case modules do
          :dynamic -> {:modules_dynamic}
          [_ | _] = mod_list -> {:modules_list, mod_list}
          [] -> {:modules_empty}
        end

      {:child_info, id, child_status, child_type, child_modules}
    end)
  end

  @doc """
  Count children in a DynamicSupervisor.

  Returns: {:child_counts, specs, active, supervisors, workers}
  """
  def count_dynamic_children(supervisor) do
    debug_log(:debug, "Counting dynamic children for supervisor: #{inspect(supervisor)}")

    counts = DynamicSupervisor.count_children(supervisor)
    debug_log(:debug, "Dynamic supervisor child counts: #{inspect(counts)}")

    # Use Map.get instead of Keyword.get!
    specs = Map.get(counts, :specs, 0)
    active = Map.get(counts, :active, 0)
    supervisors = Map.get(counts, :supervisors, 0)
    workers = Map.get(counts, :workers, 0)

    result = {:child_counts, specs, active, supervisors, workers}
    debug_log(:debug, "Returning child counts: #{inspect(result)}")
    result
  end

  # ========================================
  # REGULAR SUPERVISOR FUNCTIONS (existing)
  # ========================================

  @doc """
  Terminate a child process and convert the result to Gleam-compatible format.

  Returns:
  - {:terminate_child_ok} for :ok
  - {:terminate_child_error, :not_found} for {:error, :not_found}
  - {:terminate_child_error, :simple_one_for_one} for {:error, :simple_one_for_one}
  """
  def terminate_child(supervisor, child_id) do
    debug_log(:debug, "Terminating child '#{inspect(child_id)}' in supervisor: #{inspect(supervisor)}")

    case :supervisor.terminate_child(supervisor, child_id) do
      :ok ->
        debug_log(:info, "Child '#{inspect(child_id)}' terminated successfully")
        {:terminate_child_ok}

      {:error, :not_found} ->
        debug_log(:warning, "Child '#{inspect(child_id)}' not found for termination")
        {:terminate_child_error, :not_found}

      {:error, :simple_one_for_one} ->
        always_log(:error, "Cannot terminate child in simple_one_for_one supervisor")
        {:terminate_child_error, :simple_one_for_one}

      {:error, other} ->
        always_log(:error, "Child termination failed: #{inspect(other)}")
        {:terminate_child_error, other}
    end
  end

  def start_child_with_simple_spec(supervisor, spec_map) do
    child_id = Map.get(spec_map, "id", "unknown")
    debug_log(:debug, "Starting child '#{child_id}' with simple spec")

    # Use String.to_atom for more flexibility
    module_atom = String.to_atom(Map.get(spec_map, "start_module"))
    function_atom = String.to_atom(Map.get(spec_map, "start_function"))

    # Ensure arguments are a proper list
    args = Map.get(spec_map, "start_args", [])

    args_list =
      case args do
        list when is_list(list) -> list
        tuple when is_tuple(tuple) -> Tuple.to_list(tuple)
        single_value -> [single_value]
      end

    erlang_spec = %{
      id: Map.get(spec_map, "id"),
      start: {
        module_atom,
        function_atom,
        args_list
      },
      restart: String.to_atom(Map.get(spec_map, "restart")),
      shutdown: Map.get(spec_map, "shutdown"),
      type: String.to_atom(Map.get(spec_map, "type"))
    }

    debug_log(:debug, "Starting child with erlang spec: #{inspect(erlang_spec)}")
    :supervisor.start_child(supervisor, erlang_spec)
  end

  @doc """
  Get information about all child processes.

  Returns a list of child info tuples in Gleam format:
  {:child_info, id, child_pid_or_undefined, type, modules}
  """
  def which_children(supervisor) do
    debug_log(:debug, "Querying children for supervisor: #{inspect(supervisor)}")

    children = :supervisor.which_children(supervisor)
    debug_log(:debug, "Found #{length(children)} children")

    children
    |> Enum.map(fn {id, child, type, modules} ->
      child_status =
        case child do
          pid when is_pid(pid) -> {:child_pid, pid}
          :restarting -> {:child_restarting}
          :undefined -> {:child_undefined}
        end

      child_type =
        case type do
          :worker -> {:worker}
          :supervisor -> {:supervisor_child}
        end

      child_modules =
        case modules do
          :dynamic -> {:modules_dynamic}
          [_ | _] = mod_list -> {:modules_list, mod_list}
          [] -> {:modules_empty}
        end

      {:child_info, id, child_status, child_type, child_modules}
    end)
  end

  @doc """
  Count children by type and status.

  Returns: {:child_counts, specs, active, supervisors, workers}
  """
  def count_children(supervisor) do
    debug_log(:debug, "Counting children for supervisor: #{inspect(supervisor)}")

    counts = :supervisor.count_children(supervisor)
    debug_log(:debug, "Supervisor child counts: #{inspect(counts)}")

    specs = Keyword.get(counts, :specs, 0)
    active = Keyword.get(counts, :active, 0)
    supervisors = Keyword.get(counts, :supervisors, 0)
    workers = Keyword.get(counts, :workers, 0)

    result = {:child_counts, specs, active, supervisors, workers}
    debug_log(:debug, "Returning child counts: #{inspect(result)}")
    result
  end

  @doc """
  Delete a child specification.

  Returns:
  - {:delete_child_ok} for :ok
  - {:delete_child_error, :running} for {:error, :running}
  - {:delete_child_error, :restarting} for {:error, :restarting}
  - {:delete_child_error, :not_found} for {:error, :not_found}
  """
  def delete_child(supervisor, child_id) do
    debug_log(:debug, "Deleting child '#{inspect(child_id)}' from supervisor: #{inspect(supervisor)}")

    case :supervisor.delete_child(supervisor, child_id) do
      :ok ->
        debug_log(:info, "Child '#{inspect(child_id)}' deleted successfully")
        {:delete_child_ok}

      {:error, :running} ->
        debug_log(:warning, "Cannot delete running child '#{inspect(child_id)}'")
        {:delete_child_error, :running}

      {:error, :restarting} ->
        debug_log(:warning, "Cannot delete restarting child '#{inspect(child_id)}'")
        {:delete_child_error, :restarting}

      {:error, :not_found} ->
        debug_log(:warning, "Child '#{inspect(child_id)}' not found for deletion")
        {:delete_child_error, :not_found}

      {:error, :simple_one_for_one} ->
        always_log(:error, "Cannot delete child in simple_one_for_one supervisor")
        {:delete_child_error, :simple_one_for_one}

      {:error, other} ->
        always_log(:error, "Child deletion failed: #{inspect(other)}")
        {:delete_child_error, other}
    end
  end

  @doc """
  Restart a child process.

  Returns:
  - {:restart_child_ok, pid} for {:ok, pid}
  - {:restart_child_ok_already_started, pid} for {:ok, pid, info}
  - {:restart_child_error, reason} for {:error, reason}
  """
  def restart_child(supervisor, child_id) do
    debug_log(:debug, "Restarting child '#{inspect(child_id)}' in supervisor: #{inspect(supervisor)}")

    case :supervisor.restart_child(supervisor, child_id) do
      {:ok, pid} ->
        debug_log(:info, "Child '#{inspect(child_id)}' restarted successfully: #{inspect(pid)}")
        {:restart_child_ok, pid}

      {:ok, pid, _info} ->
        debug_log(:info, "Child '#{inspect(child_id)}' restarted (already started): #{inspect(pid)}")
        {:restart_child_ok_already_started, pid}

      {:error, :running} ->
        debug_log(:warning, "Child '#{inspect(child_id)}' is already running")
        {:restart_child_error, :running}

      {:error, :restarting} ->
        debug_log(:warning, "Child '#{inspect(child_id)}' is already restarting")
        {:restart_child_error, :restarting}

      {:error, :not_found} ->
        debug_log(:warning, "Child '#{inspect(child_id)}' not found for restart")
        {:restart_child_error, :not_found}

      {:error, :simple_one_for_one} ->
        always_log(:error, "Cannot restart child in simple_one_for_one supervisor")
        {:restart_child_error, :simple_one_for_one}

      {:error, other} ->
        always_log(:error, "Child restart failed: #{inspect(other)}")
        {:restart_child_error, other}
    end
  end

  @doc """
  Get child specification for a child.

  Returns:
  - {:get_childspec_ok, childspec} for childspec
  - {:get_childspec_error, :not_found} for {:error, :not_found}
  """
  def get_childspec(supervisor, child_id) do
    debug_log(:debug, "Getting childspec for '#{inspect(child_id)}' from supervisor: #{inspect(supervisor)}")

    case :supervisor.get_childspec(supervisor, child_id) do
      {:error, :not_found} ->
        debug_log(:warning, "Childspec for '#{inspect(child_id)}' not found")
        {:get_childspec_error, :not_found}

      childspec ->
        debug_log(:debug, "Retrieved childspec for '#{inspect(child_id)}'")
        {:get_childspec_ok, childspec}
    end
  end
end
