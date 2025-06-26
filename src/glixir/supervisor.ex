defmodule Glixir.Supervisor do
  @moduledoc """
  Elixir wrapper for OTP Supervisor functions that converts responses
  into Gleam-compatible tuple formats.
  """

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
      {:ok, pid} -> {:dynamic_supervisor_ok, pid}
      {:error, {:already_started, pid}} -> {:dynamic_supervisor_ok, pid}
      {:error, reason} -> {:dynamic_supervisor_error, reason}
    end
  end

  @doc """
  Start a named DynamicSupervisor with just a name (uses defaults).
  """
  def start_dynamic_supervisor_named(name) when is_binary(name) do
    start_dynamic_supervisor(%{"name" => name})
  end

  @doc """
  Start a DynamicSupervisor with default options.
  """
  def start_dynamic_supervisor_simple() do
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
    child_spec = %{
      id: Map.get(spec_map, "id"),
      start: {
        String.to_existing_atom(Map.get(spec_map, "start_module")),
        String.to_existing_atom(Map.get(spec_map, "start_function")),
        Map.get(spec_map, "start_args", [])
      },
      restart: String.to_existing_atom(Map.get(spec_map, "restart", "permanent")),
      shutdown: String.to_integer(Map.get(spec_map, "shutdown", "5000")),
      type: String.to_existing_atom(Map.get(spec_map, "type", "worker"))
    }

    case DynamicSupervisor.start_child(supervisor, child_spec) do
      {:ok, pid} -> {:dynamic_start_child_ok, pid}
      {:ok, pid, _info} -> {:dynamic_start_child_ok, pid}
      {:error, {:already_started, pid}} -> {:dynamic_start_child_ok, pid}
      {:error, reason} -> {:dynamic_start_child_error, reason}
    end
  end

  @doc """
  Terminate a child in a DynamicSupervisor.

  Returns:
  - {:dynamic_terminate_child_ok} for :ok
  - {:dynamic_terminate_child_error, reason} for errors
  """
  def terminate_dynamic_child(supervisor, child_pid) do
    case DynamicSupervisor.terminate_child(supervisor, child_pid) do
      :ok -> {:dynamic_terminate_child_ok}
      {:error, reason} -> {:dynamic_terminate_child_error, reason}
    end
  end

  @doc """
  Get information about all children in a DynamicSupervisor.

  Returns list of: {:dynamic_child_info, id, pid, type}
  """
  def which_dynamic_children(supervisor) do
    DynamicSupervisor.which_children(supervisor)
    |> Enum.map(fn {id, child, type, _modules} ->
      child_status =
        case child do
          pid when is_pid(pid) -> {:child_pid, pid}
          :restarting -> {:child_restarting}
          :undefined -> {:child_undefined}
        end

      child_type =
        case type do
          :worker -> {:child_worker}
          :supervisor -> {:child_supervisor}
        end

      {:dynamic_child_info, id, child_status, child_type}
    end)
  end

  @doc """
  Count children in a DynamicSupervisor.

  Returns: {:dynamic_child_counts, specs, active, supervisors, workers}
  """
  def count_dynamic_children(supervisor) do
    counts = DynamicSupervisor.count_children(supervisor)

    specs = Keyword.get(counts, :specs, 0)
    active = Keyword.get(counts, :active, 0)
    supervisors = Keyword.get(counts, :supervisors, 0)
    workers = Keyword.get(counts, :workers, 0)

    {:dynamic_child_counts, specs, active, supervisors, workers}
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
    case :supervisor.terminate_child(supervisor, child_id) do
      :ok -> {:terminate_child_ok}
      {:error, :not_found} -> {:terminate_child_error, :not_found}
      {:error, :simple_one_for_one} -> {:terminate_child_error, :simple_one_for_one}
      {:error, other} -> {:terminate_child_error, other}
    end
  end

  def start_child_with_simple_spec(supervisor, spec_map) do
    erlang_spec = %{
      id: Map.get(spec_map, "id"),
      start: {
        String.to_existing_atom(Map.get(spec_map, "start_module")),
        String.to_existing_atom(Map.get(spec_map, "start_function")),
        Map.get(spec_map, "start_args")
      },
      restart: String.to_existing_atom(Map.get(spec_map, "restart")),
      shutdown: Map.get(spec_map, "shutdown"),
      type: String.to_existing_atom(Map.get(spec_map, "type"))
    }

    :supervisor.start_child(supervisor, erlang_spec)
  end

  @doc """
  Get information about all child processes.

  Returns a list of child info tuples in Gleam format:
  {:child_info, id, child_pid_or_undefined, type, modules}
  """
  def which_children(supervisor) do
    :supervisor.which_children(supervisor)
    |> Enum.map(fn {id, child, type, modules} ->
      child_status =
        case child do
          pid when is_pid(pid) -> {:child_pid, pid}
          :restarting -> {:child_restarting}
          :undefined -> {:child_undefined}
        end

      child_type =
        case type do
          :worker -> {:child_worker}
          :supervisor -> {:child_supervisor}
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
    counts = :supervisor.count_children(supervisor)

    specs = Keyword.get(counts, :specs, 0)
    active = Keyword.get(counts, :active, 0)
    supervisors = Keyword.get(counts, :supervisors, 0)
    workers = Keyword.get(counts, :workers, 0)

    {:child_counts, specs, active, supervisors, workers}
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
    case :supervisor.delete_child(supervisor, child_id) do
      :ok -> {:delete_child_ok}
      {:error, :running} -> {:delete_child_error, :running}
      {:error, :restarting} -> {:delete_child_error, :restarting}
      {:error, :not_found} -> {:delete_child_error, :not_found}
      {:error, :simple_one_for_one} -> {:delete_child_error, :simple_one_for_one}
      {:error, other} -> {:delete_child_error, other}
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
    case :supervisor.restart_child(supervisor, child_id) do
      {:ok, pid} -> {:restart_child_ok, pid}
      {:ok, pid, _info} -> {:restart_child_ok_already_started, pid}
      {:error, :running} -> {:restart_child_error, :running}
      {:error, :restarting} -> {:restart_child_error, :restarting}
      {:error, :not_found} -> {:restart_child_error, :not_found}
      {:error, :simple_one_for_one} -> {:restart_child_error, :simple_one_for_one}
      {:error, other} -> {:restart_child_error, other}
    end
  end

  @doc """
  Get child specification for a child.

  Returns:
  - {:get_childspec_ok, childspec} for childspec
  - {:get_childspec_error, :not_found} for {:error, :not_found}
  """
  def get_childspec(supervisor, child_id) do
    case :supervisor.get_childspec(supervisor, child_id) do
      {:error, :not_found} -> {:get_childspec_error, :not_found}
      childspec -> {:get_childspec_ok, childspec}
    end
  end
end
