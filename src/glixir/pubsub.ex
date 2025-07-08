defmodule Glixir.PubSub do
  @moduledoc """
  Elixir wrapper for Phoenix.PubSub functions that converts responses
  into Gleam-compatible tuple formats.
  """
  require Logger

  @doc """
  Start a PubSub system with the given name.
  Returns:
  - {:pubsub_start_ok, pid} for successful start
  - {:pubsub_start_error, reason} for errors
  """
  def start_pubsub(name) when is_binary(name) do
    Logger.debug("[PubSub.ex] Starting PubSub: #{name}")
    pubsub_name = String.to_atom(name)
    
    # Start a supervisor with Phoenix.PubSub as a child
    children = [
      {Phoenix.PubSub, name: pubsub_name}
    ]
    
    case Supervisor.start_link(children, strategy: :one_for_one, name: :"#{name}_supervisor") do
      {:ok, supervisor_pid} ->
        # Get the PubSub process from the supervisor
        case Process.whereis(pubsub_name) do
          pid when is_pid(pid) ->
            Logger.info("[PubSub.ex] ✅ PubSub '#{name}' started successfully: #{inspect(pid)}")
            {:pubsub_start_ok, pid}
          nil ->
            Logger.error("[PubSub.ex] ❌ PubSub process not found after supervisor start")
            {:pubsub_start_error, :pubsub_not_found}
        end
      {:error, {:already_started, _pid}} ->
        # If supervisor already exists, just get the PubSub pid
        case Process.whereis(pubsub_name) do
          pid when is_pid(pid) ->
            Logger.debug("[PubSub.ex] ⚠️ PubSub '#{name}' already started: #{inspect(pid)}")
            {:pubsub_start_ok, pid}
          nil ->
            {:pubsub_start_error, :pubsub_not_found}
        end
      {:error, reason} ->
        Logger.error("[PubSub.ex] ❌ PubSub '#{name}' start failed: #{inspect(reason)}")
        {:pubsub_start_error, reason}
    end
  end

  # ... rest of your functions remain the same
  
  @doc """
  Subscribe the current process to a topic.
  Returns:
  - :pubsub_subscribe_ok for successful subscription
  - {:pubsub_subscribe_error, reason} for errors
  """
  def subscribe(pubsub_name, topic) when is_binary(pubsub_name) and is_binary(topic) do
    Logger.debug("[PubSub.ex] Subscribing to topic '#{topic}' in PubSub '#{pubsub_name}'")
    pubsub_atom = String.to_atom(pubsub_name)
    case Phoenix.PubSub.subscribe(pubsub_atom, topic) do
      :ok ->
        Logger.info("[PubSub.ex] ✅ Subscribed to topic '#{topic}'")
        :pubsub_subscribe_ok
      {:error, reason} ->
        Logger.error("[PubSub.ex] ❌ Subscribe failed for topic '#{topic}': #{inspect(reason)}")
        {:pubsub_subscribe_error, reason}
    end
  end

  @doc """
  Broadcast a message to all subscribers of a topic.
  Returns:
  - :pubsub_broadcast_ok for successful broadcast
  - {:pubsub_broadcast_error, reason} for errors
  """
  def broadcast(pubsub_name, topic, message) when is_binary(pubsub_name) and is_binary(topic) do
    Logger.debug("[PubSub.ex] Broadcasting to topic '#{topic}' in PubSub '#{pubsub_name}'")
    pubsub_atom = String.to_atom(pubsub_name)
    case Phoenix.PubSub.broadcast(pubsub_atom, topic, message) do
      :ok ->
        Logger.debug("[PubSub.ex] ✅ Broadcast sent to topic '#{topic}'")
        :pubsub_broadcast_ok
      {:error, reason} ->
        Logger.error("[PubSub.ex] ❌ Broadcast failed for topic '#{topic}': #{inspect(reason)}")
        {:pubsub_broadcast_error, reason}
    end
  end

  @doc """
  Unsubscribe the current process from a topic.
  Returns:
  - :pubsub_unsubscribe_ok for successful unsubscription
  - {:pubsub_unsubscribe_error, reason} for errors
  """
  def unsubscribe(pubsub_name, topic) when is_binary(pubsub_name) and is_binary(topic) do
    Logger.debug("[PubSub.ex] Unsubscribing from topic '#{topic}' in PubSub '#{pubsub_name}'")
    pubsub_atom = String.to_atom(pubsub_name)
    case Phoenix.PubSub.unsubscribe(pubsub_atom, topic) do
      :ok ->
        Logger.info("[PubSub.ex] ✅ Unsubscribed from topic '#{topic}'")
        :pubsub_unsubscribe_ok
      {:error, reason} ->
        Logger.error("[PubSub.ex] ❌ Unsubscribe failed for topic '#{topic}': #{inspect(reason)}")
        {:pubsub_unsubscribe_error, reason}
    end
  end
end
