defmodule TestGenServer do
  @moduledoc """
  Simple GenServer for testing glixir functionality.
  """
  use GenServer
  require Logger

  # Client API
  def start_link(initial_state \\ "default") do
    Logger.debug("Starting TestGenServer with state: #{inspect(initial_state)}")
    GenServer.start_link(__MODULE__, initial_state, [])
  end

  def start_link_named(name, initial_state \\ "default") do
    Logger.debug("Starting named TestGenServer '#{name}' with state: #{inspect(initial_state)}")
    GenServer.start_link(__MODULE__, initial_state, name: String.to_atom(name))
  end

  def ping(pid) do
    GenServer.call(pid, :ping)
  end

  def get_state(pid) do
    GenServer.call(pid, :get_state)
  end

  # Server Callbacks - Accept any argument type
  @impl true
  def init(state) do
    Logger.info("TestGenServer initialized with state: #{inspect(state)}")
    {:ok, %{original_state: state, type: get_state_type(state)}}
  end

  defp get_state_type(state) when is_binary(state), do: :string
  defp get_state_type(state) when is_list(state), do: :list
  defp get_state_type(state) when is_map(state), do: :map
  defp get_state_type(_), do: :other

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
  def handle_call(request, _from, state) do
    Logger.warning("Unknown call: #{inspect(request)}")
    {:reply, {:error, :unknown_call}, state}
  end

  @impl true
  def handle_cast(request, state) do
    Logger.debug("Handling cast: #{inspect(request)}")
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
end
