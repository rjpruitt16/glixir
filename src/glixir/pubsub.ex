defmodule Glixir.PubSub do
  @moduledoc """
  Type-safe Phoenix.PubSub bridge for Gleam actors, using JSON for interop.
  
  IMPORTANT: All PubSub names must be pre-existing atoms to prevent atom table overflow.
  Users are responsible for creating atoms safely before calling these functions.
  """

  require Logger

  # Use Gleam utils module for debug logging (updated path)
  defp debug_log(level, message) do
    :glixir@utils.debug_log(level, message)
  end
  
  # Always log (for critical errors) (updated path)
  defp always_log(level, message) do
    :glixir@utils.always_log(level, message)
  end  

  # --- START PUBSUB ---
  def start(pubsub_name) when is_atom(pubsub_name) do
    debug_log(:debug, "[PubSub.ex] Starting PubSub: #{inspect(pubsub_name)}")

    children = [
      {Phoenix.PubSub, name: pubsub_name}
    ]

    supervisor_name = :"#{pubsub_name}_supervisor"
    
    case Supervisor.start_link(children, strategy: :one_for_one, name: supervisor_name) do
      {:ok, _supervisor_pid} ->
        case Process.whereis(pubsub_name) do
          pid when is_pid(pid) ->
            always_log(:info, "[PubSub.ex] ✅ PubSub started: #{inspect(pid)}")
            {:pubsub_start_ok, pid}
          nil ->
            always_log(:error, "[PubSub.ex] ❌ PubSub process not found after supervisor start")
            {:pubsub_start_error, :pubsub_not_found}
        end

      {:error, {:already_started, _}} ->
        case Process.whereis(pubsub_name) do
          pid when is_pid(pid) ->
            debug_log(:debug, "[PubSub.ex] ⚠️ PubSub already started: #{inspect(pid)}")
            {:pubsub_start_ok, pid}
          nil ->
            {:pubsub_start_error, :pubsub_not_found}
        end

      {:error, reason} ->
        always_log(:error, "[PubSub.ex] ❌ PubSub start failed: #{inspect(reason)}")
        {:pubsub_start_error, reason}
    end
  end

  # --- SUBSCRIBE ---
  def subscribe(pubsub_name, topic, gleam_module, gleam_function)
      when is_atom(pubsub_name) and is_binary(topic) and is_binary(gleam_module) and is_binary(gleam_function) do
    
    debug_log(:debug, "[PubSub.ex] Subscribing to topic '#{topic}' (→ #{gleam_module}.#{gleam_function}/1)")

    case Phoenix.PubSub.subscribe(pubsub_name, topic) do
      :ok ->
        always_log(:info, "[PubSub.ex] ✅ Subscribed to topic '#{topic}'")
        
        # Test if the module exists BEFORE spawning
        try do
          # Gleam modules don't have "Elixir." prefix - use the name directly
          gleam_module_atom = String.to_existing_atom(gleam_module)
          debug_log(:debug, "[PubSub.ex] Module atom created: #{inspect(gleam_module_atom)}")
          
          # Test if the function exists
          gleam_function_atom = String.to_existing_atom(gleam_function)
          case function_exported?(gleam_module_atom, gleam_function_atom, 1) do
            true ->
              debug_log(:debug, "[PubSub.ex] Function confirmed: #{gleam_function}/1")
              
              # Now spawn the handler process
              debug_log(:debug, "[PubSub.ex] About to spawn handler process...")
              
              handler_pid = spawn(fn ->
                debug_log(:debug, "[PubSub.ex] Handler process started successfully")
                receive_loop(gleam_module, gleam_function)
              end)
              
              debug_log(:debug, "[PubSub.ex] Handler spawned: #{inspect(handler_pid)}")
              
              :pubsub_subscribe_ok
              
            false ->
              always_log(:error, "[PubSub.ex] ❌ Function not exported: #{gleam_module}.#{gleam_function}/1")
              {:pubsub_subscribe_error, :function_not_exported}
          end
          
        rescue
          ArgumentError ->
            always_log(:error, "[PubSub.ex] ❌ Module does not exist: #{gleam_module}")
            {:pubsub_subscribe_error, :module_not_found}
            
          error ->
            always_log(:error, "[PubSub.ex] ❌ Unexpected error during subscribe: #{inspect(error)}")
            {:pubsub_subscribe_error, error}
        end

      {:error, reason} ->
        always_log(:error, "[PubSub.ex] ❌ Subscribe failed: #{inspect(reason)}")
        {:pubsub_subscribe_error, reason}
    end
  end

  # --- BROADCAST ---
  def broadcast(pubsub_name, topic, json_message)
      when is_atom(pubsub_name) and is_binary(topic) and is_binary(json_message) do
    
    debug_log(:debug, "[PubSub.ex] Broadcasting to topic '#{topic}'")

    # Use built-in Erlang JSON instead of Jason
    case :json.decode(json_message) do
      {:ok, decoded_message} ->
        case Phoenix.PubSub.broadcast(pubsub_name, topic, decoded_message) do
          :ok ->
            always_log(:info, "[PubSub.ex] ✅ Broadcast sent to topic '#{topic}'")
            :pubsub_broadcast_ok

          {:error, reason} ->
            always_log(:error, "[PubSub.ex] ❌ Broadcast failed: #{inspect(reason)}")
            {:pubsub_broadcast_error, reason}
        end

      decoded_message when not is_tuple(decoded_message) ->
        # :json.decode returns the value directly, not {:ok, value}
        case Phoenix.PubSub.broadcast(pubsub_name, topic, decoded_message) do
          :ok ->
            always_log(:info, "[PubSub.ex] ✅ Broadcast sent to topic '#{topic}'")
            :pubsub_broadcast_ok

          {:error, reason} ->
            always_log(:error, "[PubSub.ex] ❌ Broadcast failed: #{inspect(reason)}")
            {:pubsub_broadcast_error, reason}
        end
        
      {:error, reason} ->
        always_log(:error, "[PubSub.ex] ❌ Invalid JSON: #{inspect(reason)}")
        {:pubsub_broadcast_error, :invalid_json}
    end
  rescue
    error ->
      always_log(:error, "[PubSub.ex] ❌ JSON decode error: #{inspect(error)}")
      {:pubsub_broadcast_error, :json_decode_error}
  end

  # --- UNSUBSCRIBE ---
  def unsubscribe(pubsub_name, topic)
      when is_atom(pubsub_name) and is_binary(topic) do
    
    debug_log(:debug, "[PubSub.ex] Unsubscribing from topic '#{topic}'")

    case Phoenix.PubSub.unsubscribe(pubsub_name, topic) do
      :ok ->
        always_log(:info, "[PubSub.ex] ✅ Unsubscribed from topic '#{topic}'")
        :pubsub_unsubscribe_ok

      {:error, reason} ->
        always_log(:error, "[PubSub.ex] ❌ Unsubscribe failed: #{inspect(reason)}")
        {:pubsub_unsubscribe_error, reason}
    end
  end

  # -- HANDLER LOOP --
  defp receive_loop(gleam_module, gleam_function) do
    receive do
      msg ->
        case Jason.encode(msg) do
          {:ok, json} ->
            try do
              # Don't prepend "Elixir." - the module name is already correct
              gleam_module_atom = String.to_existing_atom(gleam_module)
              gleam_function_atom = String.to_existing_atom(gleam_function)
              
              debug_log(:debug, "[PubSub.ex] Calling #{gleam_module_atom}.#{gleam_function_atom}(#{json})")
              
              apply(gleam_module_atom, gleam_function_atom, [json])
              
            rescue
              ArgumentError ->
                always_log(:error, "[PubSub.ex] ❌ Module not found: #{gleam_module}")
              
              UndefinedFunctionError ->
                always_log(:error, "[PubSub.ex] ❌ Function not found: #{gleam_module}.#{gleam_function}/1")
              
              error ->
                always_log(:error, "[PubSub.ex] ❌ Error calling handler: #{inspect(error)}")
            end

          {:error, error} ->
            always_log(:error, "[PubSub.ex] ❌ JSON encode error: #{inspect(error)}")
        end

        receive_loop(gleam_module, gleam_function)
    end
  end
end
