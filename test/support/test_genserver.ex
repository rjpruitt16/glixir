defmodule TestGenServer do
  @moduledoc """
  Simple GenServer for testing glixir functionality.
  Designed to match Gleam's calling conventions.
  """
  use GenServer
  require Logger

  # PRIMARY INTERFACE - What Gleam calls

  @doc """
  Handle multiple arguments as a list (common supervisor pattern)
  """
  def start_link(args) when is_list(args) and length(args) > 1 do
    Logger.debug("Starting TestGenServer with multiple args: #{inspect(args)}")
    # Convert multiple args to a structured state
    state = %{
      args: args,
      type: :multi_arg,
      started_at: System.system_time(:millisecond)
    }

    GenServer.start_link(__MODULE__, state, [])
  end

  @doc """
  Handle empty args list
  """
  def start_link([]) do
    Logger.debug("Starting TestGenServer with empty args")
    GenServer.start_link(__MODULE__, "default_empty", [])
  end

  @doc """
  Handle single argument
  """
  def start_link(args) when not is_list(args) do
    Logger.debug("Starting TestGenServer with single arg: #{inspect(args)}")
    GenServer.start_link(__MODULE__, args, [])
  end

  @doc """
  Handle single item list
  """
  def start_link([single_arg]) do
    Logger.debug("Starting TestGenServer with single arg in list: #{inspect(single_arg)}")
    GenServer.start_link(__MODULE__, single_arg, [])
  end

  # CONVENIENCE FUNCTIONS - For direct Elixir testing

  @doc """
  Convenience function for starting a named GenServer directly from Elixir
  """
  def start_link_named(name, initial_state \\ "default") when is_binary(name) do
    Logger.debug("Starting named TestGenServer '#{name}' with state: #{inspect(initial_state)}")
    GenServer.start_link(__MODULE__, initial_state, name: String.to_atom(name))
  end

  @doc """
  Ping the GenServer - returns :pong
  """
  def ping(pid) do
    GenServer.call(pid, :ping)
  end

  @doc """
  Get the current state
  """
  def get_state(pid) do
    GenServer.call(pid, :get_state)
  end

  # GENSERVER CALLBACKS

  @impl true
  def init(state) do
    Logger.info("TestGenServer initialized with state: #{inspect(state)}")

    # Handle different state types
    normalized_state =
      case state do
        # If it's already a map, use it
        %{} = map ->
          map

        # Convert other types to a structured state
        other ->
          %{
            original_state: other,
            type: get_state_type(other),
            started_at: System.system_time(:millisecond)
          }
      end

    {:ok, normalized_state}
  end

  @impl true
  def handle_call(:ping, _from, state) do
    Logger.debug("Handling ping call")
    {:reply, :pong, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    Logger.debug("Handling get_state call")
    {:reply, state, state}
  end

  @impl true
  def handle_call({:get, key}, _from, state) when is_map(state) do
    Logger.debug("Handling get call for key: #{inspect(key)}")
    value = Map.get(state, key)
    {:reply, value, state}
  end

  @impl true
  def handle_call({:put, key, value}, _from, state) when is_map(state) do
    Logger.debug("Handling put call: #{inspect(key)} = #{inspect(value)}")
    new_state = Map.put(state, key, value)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(request, _from, state) do
    Logger.warning("Unknown call: #{inspect(request)}")
    {:reply, {:error, :unknown_call}, state}
  end

  @impl true
  def handle_cast(:stop, state) do
    Logger.info("Received stop cast")
    {:stop, :normal, state}
  end

  @impl true
  def handle_cast({:update_state, new_state}, _old_state) do
    Logger.debug("Updating state to: #{inspect(new_state)}")
    {:noreply, new_state}
  end

  @impl true
  def handle_cast(request, state) do
    Logger.debug("Handling cast: #{inspect(request)}")
    {:noreply, state}
  end

  @impl true
  def handle_info(:timeout, state) do
    Logger.debug("Received timeout")
    {:noreply, state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("Received info: #{inspect(msg)}")
    {:noreply, state}
  end

  @impl true
  def terminate(reason, state) do
    Logger.info(
      "TestGenServer terminating - Reason: #{inspect(reason)}, State: #{inspect(state)}"
    )

    :ok
  end

  # PRIVATE HELPERS

  defp get_state_type(state) when is_binary(state), do: :string
  defp get_state_type(state) when is_list(state), do: :list
  defp get_state_type(state) when is_map(state), do: :map
  defp get_state_type(state) when is_integer(state), do: :integer
  defp get_state_type(state) when is_float(state), do: :float
  defp get_state_type(state) when is_boolean(state), do: :boolean
  defp get_state_type(state) when is_atom(state), do: :atom
  defp get_state_type(_), do: :other
end

