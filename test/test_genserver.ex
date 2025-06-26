# test/support/test_genserver.ex
defmodule TestGenServer do
  use GenServer

  def start_link(initial_state) do
    GenServer.start_link(__MODULE__, initial_state)
  end

  def init(initial_state) do
    {:ok, %{state: initial_state, started_at: System.system_time()}}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state.state, state}
  end

  def handle_call(:get_info, _from, state) do
    {:reply, state, state}
  end

  def handle_cast({:update_state, new_state}, state) do
    {:noreply, %{state | state: new_state}}
  end

  def handle_cast(:stop, state) do
    {:stop, :normal, state}
  end
end
