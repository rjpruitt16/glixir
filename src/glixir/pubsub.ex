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

    # Test if the module exists BEFORE spawning
    try do
      gleam_module_atom = String.to_existing_atom(gleam_module)
      debug_log(:debug, "[PubSub.ex] Module atom created: #{inspect(gleam_module_atom)}")
      
      # Test if the function exists
      gleam_function_atom = String.to_existing_atom(gleam_function)
      case function_exported?(gleam_module_atom, gleam_function_atom, 1) do
        true ->
          debug_log(:debug, "[PubSub.ex] Function confirmed: #{gleam_function}/1")
          
          # Spawn the handler process FIRST
          debug_log(:debug, "[PubSub.ex] About to spawn handler process...")
          
          handler_pid = spawn(fn ->
            debug_log(:debug, "[PubSub.ex] Handler process started, subscribing to PubSub...")
            
            # Subscribe from WITHIN the handler process
            case Phoenix.PubSub.subscribe(pubsub_name, topic) do
              :ok ->
                always_log(:info, "[PubSub.ex] ✅ Handler subscribed to topic '#{topic}'")
                receive_loop(gleam_module, gleam_function)
              {:error, reason} ->
                always_log(:error, "[PubSub.ex] ❌ Handler subscribe failed: #{inspect(reason)}")
            end
          end)
          
          debug_log(:debug, "[PubSub.ex] Handler spawned: #{inspect(handler_pid)}")
          
          # Give the handler a moment to subscribe
          Process.sleep(10)
          
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
  end

  # --- BROADCAST ---
  def broadcast(pubsub_name, topic, json_message)
      when is_atom(pubsub_name) and is_binary(topic) and is_binary(json_message) do
    
    debug_log(:debug, "[PubSub.ex] Broadcasting to topic '#{topic}'")

    # Use built-in Erlang JSON (no external dependencies)
    try do
      # Erlang's :json.decode/1 can return different formats depending on version
      decoded_message = case :json.decode(json_message) do
        {:ok, msg} -> msg
        msg when not is_tuple(msg) -> msg
        {:error, reason} -> 
          always_log(:error, "[PubSub.ex] ❌ Invalid JSON: #{inspect(reason)}")
          throw({:json_error, reason})
      end

      case Phoenix.PubSub.broadcast(pubsub_name, topic, decoded_message) do
        :ok ->
          always_log(:info, "[PubSub.ex] ✅ Broadcast sent to topic '#{topic}'")
          :pubsub_broadcast_ok

        {:error, reason} ->
          always_log(:error, "[PubSub.ex] ❌ Broadcast failed: #{inspect(reason)}")
          {:pubsub_broadcast_error, reason}
      end
    catch
      {:json_error, reason} ->
        {:pubsub_broadcast_error, :invalid_json}
    rescue
      error ->
        always_log(:error, "[PubSub.ex] ❌ JSON decode error: #{inspect(error)}")
        {:pubsub_broadcast_error, :json_decode_error}
    end
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

  # --- HANDLER LOOP (No Jason dependency) ---
  defp receive_loop(gleam_module, gleam_function) do
    receive do
      msg ->
        debug_log(:debug, "[PubSub.ex] 🎯 Handler received message: #{inspect(msg)}")
        
        # Use built-in Erlang JSON encoding (no Jason dependency)
        try do
          # Erlang's :json.encode/1 for encoding
          json = case :json.encode(msg) do
            {:ok, json_string} -> json_string
            json_string when is_binary(json_string) -> json_string
            {:error, reason} ->
              always_log(:error, "[PubSub.ex] ❌ JSON encode error: #{inspect(reason)}")
              throw({:json_encode_error, reason})
          end

          # Call the Gleam function
          try do
            gleam_module_atom = String.to_existing_atom(gleam_module)
            gleam_function_atom = String.to_existing_atom(gleam_function)
            
            debug_log(:debug, "[PubSub.ex] Calling #{gleam_module_atom}.#{gleam_function_atom}(#{json})")
            
            _result = apply(gleam_module_atom, gleam_function_atom, [json])
            debug_log(:debug, "[PubSub.ex] ✅ Handler call successful")
            
          rescue
            ArgumentError ->
              always_log(:error, "[PubSub.ex] ❌ Module not found: #{gleam_module}")
            
            UndefinedFunctionError ->
              always_log(:error, "[PubSub.ex] ❌ Function not found: #{gleam_module}.#{gleam_function}/1")
            
            error ->
              always_log(:error, "[PubSub.ex] ❌ Error calling handler: #{inspect(error)}")
          end

        catch
          {:json_encode_error, _reason} ->
            # Already logged, just continue
            :ok
        rescue
          error ->
            always_log(:error, "[PubSub.ex] ❌ Unexpected error in message handling: #{inspect(error)}")
        end

        receive_loop(gleam_module, gleam_function)
    end
  end
end
